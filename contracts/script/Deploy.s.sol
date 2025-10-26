// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SourceBridge.sol";
import "../src/DestinationBridge.sol";
import "../src/MockNFT.sol";

/**
 * @title DeployLocal
 * @dev Deployment script for local testing
 */
contract DeployLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockNFT
        MockNFT mockNFT = new MockNFT();
        console.log("MockNFT deployed at:", address(mockNFT));

        // Deploy SourceBridge (destination chain ID = 421614 for Arbitrum Sepolia)
        SourceBridge sourceBridge = new SourceBridge(421614);
        console.log("SourceBridge deployed at:", address(sourceBridge));

        // Deploy DestinationBridge (source chain ID = 1 for Ethereum)
        DestinationBridge destBridge = new DestinationBridge(1);
        console.log("DestinationBridge deployed at:", address(destBridge));

        // Get wrapped NFT address
        address wrappedNFT = destBridge.getWrappedNFTAddress();
        console.log("WrappedNFT deployed at:", wrappedNFT);

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MockNFT:", address(mockNFT));
        console.log("SourceBridge:", address(sourceBridge));
        console.log("DestinationBridge:", address(destBridge));
        console.log("WrappedNFT:", wrappedNFT);
        console.log("========================\n");
    }
}
