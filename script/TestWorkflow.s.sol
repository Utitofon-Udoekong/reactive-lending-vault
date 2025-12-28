// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/origin/MockToken.sol";
import "../src/origin/MockLendingPool.sol";
import "../src/destination/LendingVault.sol";

/**
 * @title TestWorkflow
 * @notice Interactive test workflow to demonstrate the reactive lending vault
 * @dev Run individual functions with: forge script script/TestWorkflow.s.sol:TestWorkflow --rpc-url $SEPOLIA_RPC_URL --broadcast --sig "functionName()"
 */
contract TestWorkflow is Script {
    function run() external {
        console.log("Test Workflow - Use individual functions:");
        console.log("  --sig 'depositToVault()'  - Deposit tokens to vault");
        console.log("  --sig 'updatePoolARates()' - Update Pool A rates to trigger rebalance");
        console.log("  --sig 'updatePoolBRates()' - Update Pool B rates");
        console.log("  --sig 'checkStatus()'     - Check current allocation and rates");
    }

    /**
     * @notice Deposit tokens to the vault
     */
    function depositToVault() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address vaultAddr = vm.envAddress("LENDING_VAULT_ADDRESS");

        MockToken token = MockToken(tokenAddr);
        LendingVault vault = LendingVault(vaultAddr);

        uint256 depositAmount = 10_000 * 1e18; // 10,000 tokens

        vm.startBroadcast(deployerPrivateKey);

        // Approve vault to spend tokens
        token.approve(vaultAddr, depositAmount);
        console.log("Approved vault for", depositAmount / 1e18, "tokens");

        // Deposit to vault
        uint256 sharesBefore = vault.sharesOf(deployer);
        uint256 shares = vault.deposit(depositAmount);
        console.log("Deposited", depositAmount / 1e18, "tokens");
        console.log("Received", shares / 1e18, "shares");
        console.log("Total shares:", vault.sharesOf(deployer) / 1e18);

        vm.stopBroadcast();

        // Check allocation
        (uint256 poolAAlloc, uint256 poolBAlloc) = vault.getAllocation();
        console.log("\nCurrent Allocation:");
        console.log("  Pool A:", poolAAlloc / 1e18, "tokens");
        console.log("  Pool B:", poolBAlloc / 1e18, "tokens");
    }

    /**
     * @notice Update Pool A rates to a higher value (triggers rebalance to A)
     */
    function updatePoolARates() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolAAddr = vm.envAddress("POOL_A_ADDRESS");

        MockLendingPool poolA = MockLendingPool(poolAAddr);

        vm.startBroadcast(deployerPrivateKey);

        // Set higher rates on Pool A to trigger rebalance
        poolA.updateRates(800, 1200, 7000); // 8% supply, 12% borrow, 70% utilization
        
        console.log("Pool A rates updated:");
        console.log("  Supply Rate: 800 bps (8%)");
        console.log("  Borrow Rate: 1200 bps (12%)");
        console.log("  Utilization: 7000 bps (70%)");
        console.log("\nRateUpdated event emitted - Reactive contract will process this!");

        vm.stopBroadcast();
    }

    /**
     * @notice Update Pool B rates to be higher than A (triggers rebalance to B)
     */
    function updatePoolBRates() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address poolBAddr = vm.envAddress("POOL_B_ADDRESS");

        MockLendingPool poolB = MockLendingPool(poolBAddr);

        vm.startBroadcast(deployerPrivateKey);

        // Set higher rates on Pool B to trigger rebalance
        poolB.updateRates(1000, 1500, 8000); // 10% supply, 15% borrow, 80% utilization
        
        console.log("Pool B rates updated:");
        console.log("  Supply Rate: 1000 bps (10%)");
        console.log("  Borrow Rate: 1500 bps (15%)");
        console.log("  Utilization: 8000 bps (80%)");
        console.log("\nRateUpdated event emitted - Reactive contract will process this!");

        vm.stopBroadcast();
    }

    /**
     * @notice Check current vault status
     */
    function checkStatus() external view {
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address poolAAddr = vm.envAddress("POOL_A_ADDRESS");
        address poolBAddr = vm.envAddress("POOL_B_ADDRESS");
        address vaultAddr = vm.envAddress("LENDING_VAULT_ADDRESS");

        MockLendingPool poolA = MockLendingPool(poolAAddr);
        MockLendingPool poolB = MockLendingPool(poolBAddr);
        LendingVault vault = LendingVault(vaultAddr);

        console.log("=== Current Status ===\n");
        
        console.log("Pool A:");
        console.log("  Supply Rate:", poolA.getSupplyRate(), "bps");
        console.log("  Total Assets:", poolA.totalAssets() / 1e18, "tokens");
        
        console.log("\nPool B:");
        console.log("  Supply Rate:", poolB.getSupplyRate(), "bps");
        console.log("  Total Assets:", poolB.totalAssets() / 1e18, "tokens");

        console.log("\nVault:");
        console.log("  Total Assets:", vault.totalAssets() / 1e18, "tokens");
        console.log("  Total Shares:", vault.totalShares() / 1e18);
        
        (uint256 poolAAlloc, uint256 poolBAlloc) = vault.getAllocation();
        console.log("  Allocation in Pool A:", poolAAlloc / 1e18, "tokens");
        console.log("  Allocation in Pool B:", poolBAlloc / 1e18, "tokens");
        
        (bool canRebal, string memory reason) = vault.canRebalance();
        console.log("  Can Rebalance:", canRebal ? "Yes" : "No");
        console.log("  Reason:", reason);
    }

    /**
     * @notice Withdraw from vault
     */
    function withdrawFromVault() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address vaultAddr = vm.envAddress("LENDING_VAULT_ADDRESS");

        LendingVault vault = LendingVault(vaultAddr);
        uint256 shares = vault.sharesOf(deployer);
        
        require(shares > 0, "No shares to withdraw");

        vm.startBroadcast(deployerPrivateKey);

        uint256 halfShares = shares / 2;
        uint256 amount = vault.withdraw(halfShares);
        
        console.log("Withdrew", halfShares / 1e18, "shares");
        console.log("Received", amount / 1e18, "tokens");
        console.log("Remaining shares:", vault.sharesOf(deployer) / 1e18);

        vm.stopBroadcast();
    }
}
