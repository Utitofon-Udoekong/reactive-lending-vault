// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/origin/MockToken.sol";
import "../src/origin/MockLendingPool.sol";

/**
 * @title MockLendingPoolTest
 * @notice Tests for the MockLendingPool contract
 */
contract MockLendingPoolTest is Test {
    MockToken public token;
    MockLendingPool public pool;
    
    address public owner;
    address public user1;
    
    uint256 constant INITIAL_BALANCE = 100_000 * 1e18;
    
    event RateUpdated(uint256 indexed newSupplyRate, uint256 indexed newBorrowRate, uint256 timestamp);
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        
        token = new MockToken("Test Token", "TT", 18);
        pool = new MockLendingPool(
            address(token),
            "Test Pool",
            500,  // 5% supply
            800,  // 8% borrow
            6000  // 60% utilization
        );
        
        token.mint(user1, INITIAL_BALANCE);
        
        vm.prank(user1);
        token.approve(address(pool), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(pool.getSupplyRate(), 500);
        assertEq(pool.getBorrowRate(), 800);
        assertEq(pool.getUtilization(), 6000);
        assertEq(pool.totalAssets(), 0);
        assertEq(pool.totalShares(), 0);
    }

    function test_Deposit() public {
        uint256 amount = 10_000 * 1e18;
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, amount, amount);
        uint256 shares = pool.deposit(amount);
        
        assertEq(shares, amount, "First deposit is 1:1");
        assertEq(pool.sharesOf(user1), amount);
        assertEq(pool.totalAssets(), amount);
        assertEq(pool.totalShares(), amount);
    }

    function test_Withdraw() public {
        uint256 amount = 10_000 * 1e18;
        
        vm.startPrank(user1);
        pool.deposit(amount);
        
        uint256 withdrawn = pool.withdraw(amount / 2);
        
        assertApproxEqRel(withdrawn, amount / 2, 0.01e18);
        assertEq(pool.sharesOf(user1), amount / 2);
        vm.stopPrank();
    }

    function test_UpdateRates() public {
        vm.expectEmit(true, true, false, true);
        emit RateUpdated(700, 1000, block.timestamp);
        
        pool.updateRates(700, 1000, 7000);
        
        assertEq(pool.getSupplyRate(), 700);
        assertEq(pool.getBorrowRate(), 1000);
        assertEq(pool.getUtilization(), 7000);
    }

    function test_UpdateRates_RevertIfTooHigh() public {
        vm.expectRevert("Supply rate too high");
        pool.updateRates(10001, 800, 6000);
    }

    function test_SimulateYield() public {
        vm.prank(user1);
        pool.deposit(10_000 * 1e18);
        
        uint256 assetsBefore = pool.totalAssets();
        pool.simulateYield(1000 * 1e18);
        
        assertEq(pool.totalAssets(), assetsBefore + 1000 * 1e18);
    }

    function test_ConvertToAssets() public {
        vm.prank(user1);
        pool.deposit(10_000 * 1e18);
        
        // Simulate yield
        pool.simulateYield(1000 * 1e18);
        
        // Shares should now convert to more assets
        uint256 assets = pool.convertToAssets(10_000 * 1e18);
        assertEq(assets, 11_000 * 1e18);
    }

    function test_ConvertToShares() public {
        vm.prank(user1);
        pool.deposit(10_000 * 1e18);
        
        pool.simulateYield(1000 * 1e18);
        
        // More assets needed for same shares
        uint256 shares = pool.convertToShares(11_000 * 1e18);
        assertEq(shares, 10_000 * 1e18);
    }
}
