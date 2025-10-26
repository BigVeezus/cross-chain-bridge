// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockNFT
 * @dev Simple ERC721 contract for testing the bridge
 */
contract MockNFT is ERC721, Ownable {
    uint256 public tokenCounter = 1; // Start from 1 instead of 0

    constructor() ERC721("MockNFT", "MNFT") Ownable(msg.sender) {}

    /**
     * @dev Mint NFT to specified address
     */
    function mint(address to) external returns (uint256) {
        uint256 tokenId = tokenCounter++;
        _mint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev Batch mint multiple NFTs
     */
    function batchMint(address to, uint256 count) external returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = tokenCounter++;
            _mint(to, tokenIds[i]);
        }
        return tokenIds;
    }

    /**
     * @dev Get total supply
     */
    function totalSupply() external view returns (uint256) {
        return tokenCounter;
    }
}
