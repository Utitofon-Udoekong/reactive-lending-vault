// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/origin/MockToken.sol";
import "../src/origin/MockLendingPool.sol";
import "../src/destination/LendingVault.sol";

/**
 * @title LendingVaultTest
 * @notice Comprehensive tests for the LendingVault contract
 */
contract LendingVaultTest is Test {
    MockToken public token;
    MockLendingPool public poolA;
    MockLendingPool public poolB;
    LendingVault public vault;

    address public owner;
    address public user1;
    address public user2;
    address public reactVM;

    uint256 constant INITIAL_BALANCE = 1_000_000 * 1e18;
    uint256 constant REBALANCE_THRESHOLD = 100; // 1%
    uint256 constant REBALANCE_COOLDOWN = 60;   // 60 seconds
    uint256 constant REBALANCE_PERCENTAGE = 5000; // 50%

    event VaultDeposit(address indexed user, uint256 amount, uint256 shares);
    event VaultWithdraw(address indexed user, uint256 amount, uint256 shares);
    event Rebalance(address indexed fromPool, address indexed toPool, uint256 amount, uint256 poolARateNew, uint256 poolBRateNew);
    event RebalanceTriggered(address indexed caller, uint256 poolARate, uint256 poolBRate, uint256 rateDiff);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        reactVM = makeAddr("reactVM");

        // Deploy token
        token = new MockToken("Test USDC", "tUSDC", 18);

        // Deploy pools with different rates
        poolA = new MockLendingPool(
            address(token),
            "Pool A",
            500,  // 5% supply
            800,  // 8% borrow
            6000  // 60% utilization
        );

        poolB = new MockLendingPool(
            address(token),
            "Pool B",
            300,  // 3% supply
            600,  // 6% borrow
            4000  // 40% utilization
        );

        // Deploy vault
        vault = new LendingVault(
            address(token),
            address(poolA),
            address(poolB),
            REBALANCE_THRESHOLD,
            REBALANCE_COOLDOWN,
            REBALANCE_PERCENTAGE
        );

        // Setup authorized ReactVM
        vault.setAuthorizedReactVM(reactVM);

        // Mint tokens to users
        token.mint(user1, INITIAL_BALANCE);
        token.mint(user2, INITIAL_BALANCE);

        // Approve vault
        vm.prank(user1);
        token.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        token.approve(address(vault), type(uint256).max);
    }

    // ===== Deposit Tests =====

    function test_Deposit_Success() public {
        uint256 depositAmount = 10_000 * 1e18;

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit VaultDeposit(user1, depositAmount, depositAmount);
        uint256 shares = vault.deposit(depositAmount);

        assertEq(shares, depositAmount, "First deposit should mint 1:1 shares");
        assertEq(vault.sharesOf(user1), depositAmount, "User should have shares");
        assertEq(vault.totalShares(), depositAmount, "Total shares should match");
    }

    function test_Deposit_AllocatesToHigherYieldPool() public {
        uint256 depositAmount = 10_000 * 1e18;

        // Pool A has 5%, Pool B has 3%, so more should go to Pool A
        vm.prank(user1);
        vault.deposit(depositAmount);

        (uint256 poolAAlloc, uint256 poolBAlloc) = vault.getAllocation();
        
        // 70% to A, 30% to B
        assertEq(poolAAlloc, (depositAmount * 70) / 100, "70% should go to Pool A");
        assertEq(poolBAlloc, (depositAmount * 30) / 100, "30% should go to Pool B");
    }

    function test_Deposit_RevertIfTooSmall() public {
        vm.prank(user1);
        vm.expectRevert("Deposit too small");
        vault.deposit(100); // Below MIN_DEPOSIT
    }

    function test_Deposit_MultipleUsers() public {
        uint256 amount1 = 10_000 * 1e18;
        uint256 amount2 = 5_000 * 1e18;

        vm.prank(user1);
        vault.deposit(amount1);

        vm.prank(user2);
        vault.deposit(amount2);

        assertEq(vault.sharesOf(user1), amount1, "User1 shares correct");
        assertEq(vault.sharesOf(user2), amount2, "User2 shares correct");
        assertEq(vault.totalShares(), amount1 + amount2, "Total shares correct");
    }

    // ===== Withdraw Tests =====

    function test_Withdraw_Success() public {
        uint256 depositAmount = 10_000 * 1e18;
        
        vm.startPrank(user1);
        vault.deposit(depositAmount);
        
        uint256 sharesToWithdraw = depositAmount / 2;
        uint256 balanceBefore = token.balanceOf(user1);
        
        vault.withdraw(sharesToWithdraw);
        
        uint256 received = token.balanceOf(user1) - balanceBefore;
        assertApproxEqRel(received, sharesToWithdraw, 0.01e18, "Should receive ~half of deposit");
        assertEq(vault.sharesOf(user1), depositAmount - sharesToWithdraw, "Shares should decrease");
        vm.stopPrank();
    }

    function test_Withdraw_RevertIfInsufficientShares() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        vm.prank(user1);
        vm.expectRevert("Insufficient shares");
        vault.withdraw(20_000 * 1e18);
    }

    function test_Withdraw_RevertIfZeroShares() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        vm.prank(user1);
        vm.expectRevert("Zero shares");
        vault.withdraw(0);
    }

    // ===== Rebalance Tests =====

    function test_ExecuteRebalance_Success() public {
        // Setup: deposit and wait for cooldown
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        // Update Pool B to have higher rate (triggers move from A to B)
        poolB.updateRates(800, 1000, 7000); // 8% vs Pool A's 5%

        // Fast forward past cooldown
        vm.warp(block.timestamp + REBALANCE_COOLDOWN + 1);

        // Execute rebalance from ReactVM
        vm.prank(reactVM);
        vault.executeRebalance(reactVM);

        // Check that funds moved to Pool B
        (uint256 poolAAlloc, uint256 poolBAlloc) = vault.getAllocation();
        assertGt(poolBAlloc, poolAAlloc, "Pool B should have more after rebalance");
    }

    function test_ExecuteRebalance_RevertIfUnauthorized() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        poolB.updateRates(800, 1000, 7000);
        vm.warp(block.timestamp + REBALANCE_COOLDOWN + 1);

        vm.prank(user1);
        vm.expectRevert("Unauthorized ReactVM");
        vault.executeRebalance(user1);
    }

    function test_ExecuteRebalance_RevertIfCooldownNotElapsed() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        poolB.updateRates(800, 1000, 7000);
        // Don't fast forward - cooldown not elapsed

        vm.prank(reactVM);
        vm.expectRevert("Cooldown not elapsed");
        vault.executeRebalance(reactVM);
    }

    function test_ExecuteRebalance_RevertIfRateDiffBelowThreshold() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        // Set similar rates (below threshold)
        poolA.updateRates(500, 800, 6000);
        poolB.updateRates(510, 810, 6100); // Only 0.1% difference

        vm.warp(block.timestamp + REBALANCE_COOLDOWN + 1);

        vm.prank(reactVM);
        vm.expectRevert("Rate diff below threshold");
        vault.executeRebalance(reactVM);
    }

    function test_ExecuteRebalance_MovesToHigherYieldPool() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        (uint256 poolABefore, uint256 poolBBefore) = vault.getAllocation();

        // Make Pool A much higher
        poolA.updateRates(1000, 1500, 8000); // 10% vs Pool B's 3%

        vm.warp(block.timestamp + REBALANCE_COOLDOWN + 1);

        vm.prank(reactVM);
        vault.executeRebalance(reactVM);

        (uint256 poolAAfter, uint256 poolBAfter) = vault.getAllocation();
        
        // Pool A should have more than before
        assertGt(poolAAfter, poolABefore, "Pool A should increase");
        assertLt(poolBAfter, poolBBefore, "Pool B should decrease");
    }

    // ===== View Function Tests =====

    function test_TotalAssets_IncludesAllPools() public {
        uint256 depositAmount = 10_000 * 1e18;
        
        vm.prank(user1);
        vault.deposit(depositAmount);

        uint256 totalAssets = vault.totalAssets();
        assertApproxEqRel(totalAssets, depositAmount, 0.01e18, "Total assets should match deposit");
    }

    function test_GetCurrentRates() public {
        (uint256 rateA, uint256 rateB) = vault.getCurrentRates();
        assertEq(rateA, 500, "Pool A rate should be 500");
        assertEq(rateB, 300, "Pool B rate should be 300");
    }

    function test_CanRebalance_ReturnsFalseBeforeCooldown() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        poolB.updateRates(800, 1000, 7000);

        // First warp past initial cooldown
        vm.warp(block.timestamp + REBALANCE_COOLDOWN + 1);

        (bool canRebal, ) = vault.canRebalance();
        assertTrue(canRebal, "Should be able to rebalance after initial cooldown");

        // Execute rebalance
        vm.prank(reactVM);
        vault.executeRebalance(reactVM);

        // Check again immediately after - should be in cooldown
        (canRebal, ) = vault.canRebalance();
        assertFalse(canRebal, "Should not be able to rebalance during cooldown");
    }

    // ===== Admin Function Tests =====

    function test_SetAuthorizedReactVM() public {
        address newReactVM = makeAddr("newReactVM");
        vault.setAuthorizedReactVM(newReactVM);
        assertEq(vault.authorizedReactVM(), newReactVM);
    }

    function test_SetRebalanceThreshold() public {
        vault.setRebalanceThreshold(200);
        assertEq(vault.rebalanceThreshold(), 200);
    }

    function test_SetRebalanceCooldown() public {
        vault.setRebalanceCooldown(120);
        assertEq(vault.rebalanceCooldown(), 120);
    }

    function test_SetRebalancePercentage() public {
        vault.setRebalancePercentage(7500);
        assertEq(vault.rebalancePercentage(), 7500);
    }

    function test_OnlyOwnerCanSetParameters() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.setRebalanceThreshold(200);
    }

    // ===== Fuzz Tests =====

    function testFuzz_Deposit(uint256 amount) public {
        // Ensure minimum deposit is met
        uint256 minDeposit = vault.MIN_DEPOSIT();
        amount = bound(amount, minDeposit, INITIAL_BALANCE);
        
        vm.prank(user1);
        uint256 shares = vault.deposit(amount);
        
        assertGt(shares, 0, "Should receive shares");
        assertEq(vault.sharesOf(user1), shares, "Shares should be recorded");
    }

    function testFuzz_DepositAndWithdraw(uint256 depositAmount, uint256 withdrawPercent) public {
        // Ensure minimum deposit is met
        uint256 minDeposit = vault.MIN_DEPOSIT();
        depositAmount = bound(depositAmount, minDeposit, INITIAL_BALANCE / 2);
        withdrawPercent = bound(withdrawPercent, 1, 100);
        
        vm.startPrank(user1);
        uint256 shares = vault.deposit(depositAmount);
        
        uint256 sharesToWithdraw = (shares * withdrawPercent) / 100;
        if (sharesToWithdraw > 0) {
            vault.withdraw(sharesToWithdraw);
            assertEq(vault.sharesOf(user1), shares - sharesToWithdraw);
        }
        vm.stopPrank();
    }

    // ===== Edge Case Tests =====

    function test_EmptyVaultOperations() public {
        assertEq(vault.totalAssets(), 0, "Empty vault should have 0 assets");
        assertEq(vault.totalShares(), 0, "Empty vault should have 0 shares");
    }

    function test_YieldAccrual() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        uint256 assetsBefore = vault.totalAssets();

        // Simulate yield in pools
        poolA.simulateYield(100 * 1e18);
        poolB.simulateYield(50 * 1e18);

        uint256 assetsAfter = vault.totalAssets();
        assertGt(assetsAfter, assetsBefore, "Total assets should increase with yield");
    }

    function test_MultipleRebalances() public {
        vm.prank(user1);
        vault.deposit(10_000 * 1e18);

        // Wait for initial cooldown
        vm.warp(block.timestamp + REBALANCE_COOLDOWN + 1);

        // First rebalance: favor Pool B
        poolB.updateRates(800, 1000, 7000);
        vm.prank(reactVM);
        vault.executeRebalance(reactVM);

        (uint256 allocA1, ) = vault.getAllocation();

        // Wait for cooldown again
        vm.warp(block.timestamp + REBALANCE_COOLDOWN + 1);

        // Second rebalance: favor Pool A
        poolA.updateRates(1200, 1800, 8000);
        poolB.updateRates(400, 700, 5000);
        vm.prank(reactVM);
        vault.executeRebalance(reactVM);

        (uint256 allocA2, ) = vault.getAllocation();

        // Pool A should now have more
        assertGt(allocA2, allocA1, "Pool A should have more after second rebalance");
    }
}
