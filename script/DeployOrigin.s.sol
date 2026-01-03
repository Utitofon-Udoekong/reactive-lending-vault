// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/origin/MockToken.sol";
import "../src/origin/MockLendingPool.sol";
import "../src/destination/LendingVault.sol";

/**
 * @title DeployOriginContracts
 * @notice Deploys the origin contracts (token, pools, vault) on Ethereum Sepolia
 * @dev Run with: forge script script/DeployOrigin.s.sol:DeployOriginContracts --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 */
contract DeployOriginContracts is Script {
    // Configuration
    uint256 constant POOL_A_INITIAL_SUPPLY_RATE = 500; // 5% APY
    uint256 constant POOL_A_INITIAL_BORROW_RATE = 800; // 8% APY
    uint256 constant POOL_A_INITIAL_UTILIZATION = 6000; // 60%

    uint256 constant POOL_B_INITIAL_SUPPLY_RATE = 300; // 3% APY
    uint256 constant POOL_B_INITIAL_BORROW_RATE = 600; // 6% APY
    uint256 constant POOL_B_INITIAL_UTILIZATION = 4000; // 40%

    uint256 constant REBALANCE_THRESHOLD = 100; // 1% rate difference triggers rebalance
    uint256 constant REBALANCE_COOLDOWN = 60; // 60 seconds between rebalances
    uint256 constant REBALANCE_PERCENTAGE = 9000; // 90% of funds moved on rebalance

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Origin Contracts to Sepolia");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock Token (USDC-like)
        MockToken token = new MockToken("Mock USDC", "mUSDC", 18);
        console.log("MockToken deployed at:", address(token));

        // 2. Deploy Lending Pool A
        MockLendingPool poolA = new MockLendingPool(
            address(token),
            "Lending Pool A",
            POOL_A_INITIAL_SUPPLY_RATE,
            POOL_A_INITIAL_BORROW_RATE,
            POOL_A_INITIAL_UTILIZATION
        );
        console.log("Pool A deployed at:", address(poolA));

        // 3. Deploy Lending Pool B
        MockLendingPool poolB = new MockLendingPool(
            address(token),
            "Lending Pool B",
            POOL_B_INITIAL_SUPPLY_RATE,
            POOL_B_INITIAL_BORROW_RATE,
            POOL_B_INITIAL_UTILIZATION
        );
        console.log("Pool B deployed at:", address(poolB));

        // 4. Deploy Lending Vault
        LendingVault vault = new LendingVault(
            address(token),
            address(poolA),
            address(poolB),
            REBALANCE_THRESHOLD,
            REBALANCE_COOLDOWN,
            REBALANCE_PERCENTAGE
        );
        console.log("LendingVault deployed at:", address(vault));

        // 5. Mint tokens to deployer for testing
        token.mint(deployer, 1_000_000 * 1e18);
        console.log("Minted 1,000,000 tokens to deployer");

        vm.stopBroadcast();

        // Output deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Sepolia");
        console.log("MockToken:", address(token));
        console.log("Pool A:", address(poolA));
        console.log("Pool B:", address(poolB));
        console.log("LendingVault:", address(vault));
        console.log("\nNext Steps:");
        console.log("1. Deploy Reactive Contract on Reactive Network");
        console.log("2. Set authorizedReactVM on LendingVault");
        console.log("3. Test with deposits and rate changes");
    }
}
