// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/reactive/YieldMonitorReactive.sol";

/**
 * @title DeployReactive
 * @notice Deploys the Reactive Smart Contract on Reactive Network (Lasna Testnet)
 * @dev Run with: forge script script/DeployReactive.s.sol:DeployReactive --rpc-url https://lasna-rpc.rnk.dev/ --broadcast
 */
contract DeployReactive is Script {
    // Sepolia Chain ID
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;

    // Configuration
    uint256 constant REBALANCE_THRESHOLD = 100; // 1% rate difference
    uint256 constant MIN_BLOCKS_BETWEEN_REBALANCE = 5; // ~1 minute on Sepolia

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read deployed origin contract addresses from environment
        address poolA = vm.envAddress("POOL_A_ADDRESS");
        address poolB = vm.envAddress("POOL_B_ADDRESS");
        address lendingVault = vm.envAddress("LENDING_VAULT_ADDRESS");

        console.log("Deploying Reactive Contract to Reactive Lasna Testnet");
        console.log("Deployer:", deployer);
        console.log("Pool A (Sepolia):", poolA);
        console.log("Pool B (Sepolia):", poolB);
        console.log("LendingVault (Sepolia):", lendingVault);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy YieldMonitorReactive
        YieldMonitorReactive reactive = new YieldMonitorReactive(
            SEPOLIA_CHAIN_ID, // origin chain
            SEPOLIA_CHAIN_ID, // destination chain (same for this demo)
            poolA,
            poolB,
            lendingVault,
            REBALANCE_THRESHOLD,
            MIN_BLOCKS_BETWEEN_REBALANCE
        );
        console.log("YieldMonitorReactive deployed at:", address(reactive));

        vm.stopBroadcast();

        // Output deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Reactive Lasna Testnet");
        console.log("YieldMonitorReactive:", address(reactive));
        console.log("\nNext Steps:");
        console.log(
            "1. Update LendingVault.setAuthorizedReactVM() with deployer address"
        );
        console.log("   (ReactVM ID = deployer:", deployer, ")");
        console.log(
            "2. Trigger rate updates on pools to test reactive monitoring"
        );
    }
}
