// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title SourceBridge
 * @dev Locks NFTs on the source chain and emits events for the relayer
 */
contract SourceBridge is Ownable {
    // Mapping: nftContract => tokenId => locked
    mapping(address => mapping(uint256 => bool)) public lockedNFTs;
    
    // Mapping: bridgeId => completed
    mapping(bytes32 => bool) public completedBridges;
    
    // Counter for unique bridge IDs
    uint256 public bridgeNonce;
    
    // Destination chain ID
    uint256 public immutable destinationChainId;
    
    // Events
    event NFTLocked(
        bytes32 indexed bridgeId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address owner,
        uint256 destinationChainId,
        uint256 timestamp
    );
    
    event NFTUnlocked(
        bytes32 indexed bridgeId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address owner
    );
    
    event BatchLocked(
        bytes32[] bridgeIds,
        bytes32 merkleRoot,
        uint256 count
    );

    constructor(uint256 _destinationChainId) Ownable(msg.sender) {
        destinationChainId = _destinationChainId;
    }

    /**
     * @dev Lock an NFT to bridge it to another chain
     */
    function lockNFT(
        address nftContract,
        uint256 tokenId
    ) external returns (bytes32 bridgeId) {
        require(!lockedNFTs[nftContract][tokenId], "NFT already locked");
        
        // Transfer NFT to bridge
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        
        // Mark as locked
        lockedNFTs[nftContract][tokenId] = true;
        
        // Generate unique bridge ID
        bridgeId = keccak256(
            abi.encodePacked(
                block.chainid,
                nftContract,
                tokenId,
                msg.sender,
                bridgeNonce++,
                block.timestamp
            )
        );
        
        completedBridges[bridgeId] = true;
        
        emit NFTLocked(
            bridgeId,
            nftContract,
            tokenId,
            msg.sender,
            destinationChainId,
            block.timestamp
        );
        
        return bridgeId;
    }

    /**
     * @dev Batch lock multiple NFTs (gas optimization via Merkle tree)
     */
    function batchLockNFTs(
        address[] calldata nftContracts,
        uint256[] calldata tokenIds
    ) external returns (bytes32[] memory bridgeIds, bytes32 merkleRoot) {
        require(nftContracts.length == tokenIds.length, "Array length mismatch");
        require(nftContracts.length > 0, "Empty arrays");
        
        bridgeIds = new bytes32[](nftContracts.length);
        
        for (uint256 i = 0; i < nftContracts.length; i++) {
            require(!lockedNFTs[nftContracts[i]][tokenIds[i]], "NFT already locked");
            
            // Transfer NFT
            IERC721(nftContracts[i]).transferFrom(
                msg.sender,
                address(this),
                tokenIds[i]
            );
            
            // Mark as locked
            lockedNFTs[nftContracts[i]][tokenIds[i]] = true;
            
            // Generate bridge ID
            bridgeIds[i] = keccak256(
                abi.encodePacked(
                    block.chainid,
                    nftContracts[i],
                    tokenIds[i],
                    msg.sender,
                    bridgeNonce++,
                    block.timestamp
                )
            );
            
            completedBridges[bridgeIds[i]] = true;
            
            emit NFTLocked(
                bridgeIds[i],
                nftContracts[i],
                tokenIds[i],
                msg.sender,
                destinationChainId,
                block.timestamp
            );
        }
        
        // Calculate Merkle root for batch (create a copy to avoid modifying original)
        bytes32[] memory bridgeIdsCopy = new bytes32[](bridgeIds.length);
        for (uint256 i = 0; i < bridgeIds.length; i++) {
            bridgeIdsCopy[i] = bridgeIds[i];
        }
        merkleRoot = calculateMerkleRoot(bridgeIdsCopy);
        
        emit BatchLocked(bridgeIds, merkleRoot, nftContracts.length);
        
        return (bridgeIds, merkleRoot);
    }

    /**
     * @dev Unlock NFT when returning from destination chain
     * Requires ZK proof verification (simplified for demo)
     */
    function unlockNFT(
        address nftContract,
        uint256 tokenId,
        address recipient,
        bytes32 bridgeId,
        bytes calldata zkProof
    ) external onlyOwner {
        require(lockedNFTs[nftContract][tokenId], "NFT not locked");
        require(completedBridges[bridgeId], "Invalid bridge ID");
        
        // In production: verify ZK proof here
        require(verifyZKProof(zkProof, bridgeId), "Invalid ZK proof");
        
        // Unlock and transfer
        lockedNFTs[nftContract][tokenId] = false;
        IERC721(nftContract).transferFrom(address(this), recipient, tokenId);
        
        emit NFTUnlocked(bridgeId, nftContract, tokenId, recipient);
    }

    /**
     * @dev Simplified ZK proof verification (mock for demo)
     * In production: integrate with Groth16/Plonk verifier
     */
    function verifyZKProof(
        bytes calldata proof,
        bytes32 bridgeId
    ) public pure returns (bool) {
        // Mock verification - always returns true if proof length is correct
        // In production: call verifier contract with proof and public inputs
        return proof.length == 128 && bridgeId != bytes32(0);
    }

    /**
     * @dev Calculate Merkle root from bridge IDs
     */
    function calculateMerkleRoot(
        bytes32[] memory leaves
    ) public pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];
        
        uint256 n = leaves.length;
        uint256 offset = 0;
        
        while (n > 1) {
            for (uint256 i = 0; i < n / 2; i++) {
                leaves[offset + i] = keccak256(
                    abi.encodePacked(
                        leaves[offset + i * 2],
                        leaves[offset + i * 2 + 1]
                    )
                );
            }
            offset += n / 2;
            n = n / 2 + (n % 2);
        }
        
        return leaves[0];
    }

    /**
     * @dev Check if NFT is locked
     */
    function isLocked(
        address nftContract,
        uint256 tokenId
    ) external view returns (bool) {
        return lockedNFTs[nftContract][tokenId];
    }
}