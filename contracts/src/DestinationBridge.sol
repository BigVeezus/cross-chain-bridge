// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title DestinationBridge
 * @dev Mints wrapped NFTs on the destination chain after ZK proof verification
 */
contract DestinationBridge is Ownable {
    // Mapping: bridgeId => minted
    mapping(bytes32 => bool) public mintedBridges;
    
    // Counter for wrapped token IDs
    uint256 public wrappedTokenCounter;
    
    // Source chain ID
    uint256 public immutable sourceChainId;
    
    // Wrapped NFT contract
    WrappedNFT public immutable wrappedNFT;
    
    // Events
    event NFTMinted(
        bytes32 indexed bridgeId,
        address indexed recipient,
        uint256 wrappedTokenId,
        address originalContract,
        uint256 originalTokenId,
        uint256 timestamp
    );
    
    event BatchMinted(
        bytes32[] bridgeIds,
        address[] recipients,
        uint256[] wrappedTokenIds,
        bytes32 merkleRoot
    );

    constructor(uint256 _sourceChainId) Ownable(msg.sender) {
        sourceChainId = _sourceChainId;
        wrappedNFT = new WrappedNFT();
    }

    /**
     * @dev Mint wrapped NFT after ZK proof verification
     */
    function mintWrappedNFT(
        address recipient,
        address originalContract,
        uint256 originalTokenId,
        bytes32 bridgeId,
        bytes calldata zkProof
    ) external onlyOwner returns (uint256 wrappedTokenId) {
        require(!mintedBridges[bridgeId], "Bridge already processed");
        
        // Verify ZK proof
        require(verifyZKProof(zkProof, bridgeId), "Invalid ZK proof");
        
        // Mark as minted
        mintedBridges[bridgeId] = true;
        
        // Mint wrapped NFT
        wrappedTokenId = ++wrappedTokenCounter;
        wrappedNFT.mint(recipient, wrappedTokenId, originalContract, originalTokenId);
        
        emit NFTMinted(
            bridgeId,
            recipient,
            wrappedTokenId,
            originalContract,
            originalTokenId,
            block.timestamp
        );
        
        return wrappedTokenId;
    }

    /**
     * @dev Batch mint wrapped NFTs with Merkle root verification
     */
    function batchMintWrappedNFTs(
        address[] calldata recipients,
        address[] calldata originalContracts,
        uint256[] calldata originalTokenIds,
        bytes32[] calldata bridgeIds,
        bytes32 merkleRoot,
        bytes calldata zkProof
    ) external onlyOwner returns (uint256[] memory wrappedTokenIds) {
        require(recipients.length == originalContracts.length, "Array length mismatch");
        require(recipients.length == originalTokenIds.length, "Array length mismatch");
        require(recipients.length == bridgeIds.length, "Array length mismatch");
        require(recipients.length > 0, "Empty arrays");
        
        // Verify Merkle root
        require(verifyMerkleRoot(bridgeIds, merkleRoot), "Invalid Merkle root");
        
        // Verify ZK proof for batch
        require(verifyZKProof(zkProof, merkleRoot), "Invalid ZK proof");
        
        wrappedTokenIds = new uint256[](recipients.length);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(!mintedBridges[bridgeIds[i]], "Bridge already processed");
            
            // Mark as minted
            mintedBridges[bridgeIds[i]] = true;
            
            // Mint wrapped NFT
            wrappedTokenIds[i] = ++wrappedTokenCounter;
            wrappedNFT.mint(
                recipients[i],
                wrappedTokenIds[i],
                originalContracts[i],
                originalTokenIds[i]
            );
            
            emit NFTMinted(
                bridgeIds[i],
                recipients[i],
                wrappedTokenIds[i],
                originalContracts[i],
                originalTokenIds[i],
                block.timestamp
            );
        }
        
        emit BatchMinted(bridgeIds, recipients, wrappedTokenIds, merkleRoot);
        
        return wrappedTokenIds;
    }

    /**
     * @dev Burn wrapped NFT to initiate return bridge
     */
    function burnWrappedNFT(
        uint256 wrappedTokenId,
        bytes32 bridgeId,
        bytes calldata zkProof
    ) external {
        require(wrappedNFT.ownerOf(wrappedTokenId) == msg.sender, "Not owner");
        
        // Verify ZK proof for burn
        require(verifyZKProof(zkProof, bridgeId), "Invalid ZK proof");
        
        // Burn wrapped NFT
        wrappedNFT.burn(wrappedTokenId);
        
        // Emit event for source chain relayer
        emit NFTMinted(
            bridgeId,
            msg.sender,
            wrappedTokenId,
            address(0), // Will be filled by relayer
            0, // Will be filled by relayer
            block.timestamp
        );
    }

    /**
     * @dev Simplified ZK proof verification (mock for demo)
     * In production: integrate with Groth16/Plonk verifier
     */
    function verifyZKProof(
        bytes calldata proof,
        bytes32 publicInput
    ) public pure returns (bool) {
        // Mock verification - always returns true if proof length is correct
        // In production: call verifier contract with proof and public inputs
        return proof.length == 128 && publicInput != bytes32(0);
    }

    /**
     * @dev Verify Merkle root against bridge IDs
     */
    function verifyMerkleRoot(
        bytes32[] calldata leaves,
        bytes32 root
    ) public pure returns (bool) {
        if (leaves.length == 0) return root == bytes32(0);
        if (leaves.length == 1) return leaves[0] == root;
        
        // Calculate Merkle root using the same algorithm as SourceBridge
        bytes32[] memory nodes = new bytes32[](leaves.length);
        for (uint256 i = 0; i < leaves.length; i++) {
            nodes[i] = leaves[i];
        }
        
        uint256 n = leaves.length;
        uint256 offset = 0;
        
        while (n > 1) {
            for (uint256 i = 0; i < n / 2; i++) {
                nodes[offset + i] = keccak256(
                    abi.encodePacked(
                        nodes[offset + i * 2],
                        nodes[offset + i * 2 + 1]
                    )
                );
            }
            offset += n / 2;
            n = n / 2 + (n % 2);
        }
        
        return nodes[0] == root;
    }

    /**
     * @dev Get wrapped NFT contract address
     */
    function getWrappedNFTAddress() external view returns (address) {
        return address(wrappedNFT);
    }

    /**
     * @dev Check if bridge ID has been minted
     */
    function isMinted(bytes32 bridgeId) external view returns (bool) {
        return mintedBridges[bridgeId];
    }
}

/**
 * @title WrappedNFT
 * @dev ERC721 contract for wrapped NFTs on destination chain
 */
contract WrappedNFT is ERC721, Ownable {
    // Mapping: tokenId => original contract
    mapping(uint256 => address) public originalContracts;
    
    // Mapping: tokenId => original token ID
    mapping(uint256 => uint256) public originalTokenIds;
    
    // Mapping: tokenId => bridge ID
    mapping(uint256 => bytes32) public bridgeIds;

    constructor() ERC721("WrappedNFT", "WNFT") Ownable(msg.sender) {}

    /**
     * @dev Mint wrapped NFT (only callable by bridge)
     */
    function mint(
        address to,
        uint256 tokenId,
        address originalContract,
        uint256 originalTokenId
    ) external onlyOwner {
        _mint(to, tokenId);
        originalContracts[tokenId] = originalContract;
        originalTokenIds[tokenId] = originalTokenId;
    }

    /**
     * @dev Burn wrapped NFT (only callable by bridge)
     */
    function burn(uint256 tokenId) external {
        require(msg.sender == owner(), "Only bridge can burn");
        _burn(tokenId);
    }

    /**
     * @dev Get original NFT info
     */
    function getOriginalInfo(uint256 tokenId) external view returns (address, uint256) {
        return (originalContracts[tokenId], originalTokenIds[tokenId]);
    }
}
