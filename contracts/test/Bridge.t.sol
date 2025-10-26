// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SourceBridge.sol";
import "../src/DestinationBridge.sol";
import "../src/MockNFT.sol";

contract BridgeTest is Test {
    SourceBridge sourceBridge;
    DestinationBridge destBridge;
    MockNFT mockNFT;
    
    address owner = address(this);
    address user = address(0x1);
    
    bytes constant MOCK_ZK_PROOF = hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

    function setUp() public {
        // Deploy contracts
        sourceBridge = new SourceBridge(421614);
        destBridge = new DestinationBridge(1);
        mockNFT = new MockNFT();
        
        // Mint test NFTs to user
        vm.startPrank(user);
        mockNFT.mint(user);
        mockNFT.mint(user);
        mockNFT.mint(user);
        vm.stopPrank();
    }

    function testLockNFT() public {
        vm.startPrank(user);
        
        // Approve bridge
        mockNFT.setApprovalForAll(address(sourceBridge), true);
        
        // Lock NFT
        bytes32 bridgeId = sourceBridge.lockNFT(address(mockNFT), 1);
        
        vm.stopPrank();
        
        // Verify NFT is locked
        assertTrue(sourceBridge.isLocked(address(mockNFT), 1));
        assertEq(mockNFT.ownerOf(1), address(sourceBridge));
        assertTrue(bridgeId != bytes32(0));
    }

    function testBatchLockNFTs() public {
        vm.startPrank(user);
        
        mockNFT.setApprovalForAll(address(sourceBridge), true);
        
        address[] memory nftContracts = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        
        nftContracts[0] = address(mockNFT);
        nftContracts[1] = address(mockNFT);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        
        (bytes32[] memory bridgeIds, bytes32 merkleRoot) = sourceBridge.batchLockNFTs(
            nftContracts,
            tokenIds
        );
        
        vm.stopPrank();
        
        // Verify both NFTs are locked
        assertTrue(sourceBridge.isLocked(address(mockNFT), 1));
        assertTrue(sourceBridge.isLocked(address(mockNFT), 2));
        assertEq(bridgeIds.length, 2);
        assertTrue(merkleRoot != bytes32(0));
    }

    function testMintWrappedNFT() public {
        // First lock NFT on source
        vm.startPrank(user);
        mockNFT.setApprovalForAll(address(sourceBridge), true);
        bytes32 bridgeId = sourceBridge.lockNFT(address(mockNFT), 1);
        vm.stopPrank();
        
        // Mint wrapped NFT on destination
        uint256 wrappedTokenId = destBridge.mintWrappedNFT(
            user,
            address(mockNFT),
            1,
            bridgeId,
            MOCK_ZK_PROOF
        );
        
        // Verify wrapped NFT was minted
        address wrappedNFTAddr = destBridge.getWrappedNFTAddress();
        WrappedNFT wrappedNFT = WrappedNFT(wrappedNFTAddr);
        
        assertEq(wrappedNFT.ownerOf(wrappedTokenId), user);
        assertTrue(destBridge.isMinted(bridgeId));
        
        (address originalContract, uint256 originalTokenId) = wrappedNFT.getOriginalInfo(wrappedTokenId);
        assertEq(originalContract, address(mockNFT));
        assertEq(originalTokenId, 1);
    }

    function testBatchMintWrappedNFTs() public {
        // Lock multiple NFTs
        vm.startPrank(user);
        mockNFT.setApprovalForAll(address(sourceBridge), true);
        
        address[] memory nftContracts = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        nftContracts[0] = address(mockNFT);
        nftContracts[1] = address(mockNFT);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        
        (bytes32[] memory bridgeIds, bytes32 merkleRoot) = sourceBridge.batchLockNFTs(
            nftContracts,
            tokenIds
        );
        vm.stopPrank();
        
        // Batch mint wrapped NFTs
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user;
        
        uint256[] memory wrappedTokenIds = destBridge.batchMintWrappedNFTs(
            recipients,
            nftContracts,
            tokenIds,
            bridgeIds,
            merkleRoot,
            MOCK_ZK_PROOF
        );
        
        // Verify both wrapped NFTs were minted
        address wrappedNFTAddr = destBridge.getWrappedNFTAddress();
        WrappedNFT wrappedNFT = WrappedNFT(wrappedNFTAddr);
        
        assertEq(wrappedNFT.ownerOf(wrappedTokenIds[0]), user);
        assertEq(wrappedNFT.ownerOf(wrappedTokenIds[1]), user);
    }

    function testBurnAndUnlock() public {
        // Lock on source
        vm.startPrank(user);
        mockNFT.setApprovalForAll(address(sourceBridge), true);
        bytes32 bridgeId = sourceBridge.lockNFT(address(mockNFT), 1);
        vm.stopPrank();
        
        // Mint on destination
        uint256 wrappedTokenId = destBridge.mintWrappedNFT(
            user,
            address(mockNFT),
            1,
            bridgeId,
            MOCK_ZK_PROOF
        );
        
        // Burn wrapped NFT
        vm.prank(user);
        destBridge.burnWrappedNFT(wrappedTokenId, bridgeId, MOCK_ZK_PROOF);
        
        // Unlock on source
        sourceBridge.unlockNFT(
            address(mockNFT),
            1,
            user,
            bridgeId,
            MOCK_ZK_PROOF
        );
        
        // Verify NFT is back with user
        assertEq(mockNFT.ownerOf(1), user);
        assertFalse(sourceBridge.isLocked(address(mockNFT), 1));
    }

    function testCannotLockAlreadyLockedNFT() public {
        vm.startPrank(user);
        mockNFT.setApprovalForAll(address(sourceBridge), true);
        sourceBridge.lockNFT(address(mockNFT), 1);
        
        vm.expectRevert("NFT already locked");
        sourceBridge.lockNFT(address(mockNFT), 1);
        vm.stopPrank();
    }

    function testCannotMintTwice() public {
        vm.startPrank(user);
        mockNFT.setApprovalForAll(address(sourceBridge), true);
        bytes32 bridgeId = sourceBridge.lockNFT(address(mockNFT), 1);
        vm.stopPrank();
        
        destBridge.mintWrappedNFT(
            user,
            address(mockNFT),
            1,
            bridgeId,
            MOCK_ZK_PROOF
        );
        
        vm.expectRevert("Bridge already processed");
        destBridge.mintWrappedNFT(
            user,
            address(mockNFT),
            1,
            bridgeId,
            MOCK_ZK_PROOF
        );
    }

    function testZKProofVerification() public view {
        bytes32 bridgeId = keccak256("test");
        
        // Valid proof
        assertTrue(sourceBridge.verifyZKProof(MOCK_ZK_PROOF, bridgeId));
        
        // Invalid proof (wrong length)
        bytes memory invalidProof = hex"1234";
        assertFalse(sourceBridge.verifyZKProof(invalidProof, bridgeId));
    }

    function testMerkleRootCalculation() public view {
        bytes32[] memory leaves = new bytes32[](4);
        leaves[0] = keccak256("leaf1");
        leaves[1] = keccak256("leaf2");
        leaves[2] = keccak256("leaf3");
        leaves[3] = keccak256("leaf4");
        
        bytes32 root = sourceBridge.calculateMerkleRoot(leaves);
        assertTrue(root != bytes32(0));
    }
}