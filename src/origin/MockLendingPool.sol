// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ILendingPool.sol";

/**
 * @title MockLendingPool
 * @notice A mock lending pool for demonstration purposes
 * @dev Simulates a lending pool with configurable interest rates
 *
 * This contract represents one of the lending markets (Pool A or Pool B)
 * that the vault will allocate funds to. It emits RateUpdated events
 * that the Reactive Contract monitors to trigger rebalancing.
 */
contract MockLendingPool is ILendingPool, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The underlying asset token
    IERC20 public immutable asset;

    /// @notice Pool name for identification
    string public name;

    /// @notice Current supply rate in basis points (e.g., 500 = 5%)
    uint256 public supplyRate;

    /// @notice Current borrow rate in basis points
    uint256 public borrowRate;

    /// @notice Simulated utilization rate
    uint256 public utilization;

    /// @notice Total assets deposited
    uint256 public override totalAssets;

    /// @notice Total shares minted
    uint256 public override totalShares;

    /// @notice Mapping of user shares
    mapping(address => uint256) private _shares;

    /// @notice Minimum deposit amount
    uint256 public constant MIN_DEPOSIT = 1e6; // 0.000001 tokens (for 18 decimals)

    /// @notice Event emitted when rates are manually updated
    event RatesManuallyUpdated(
        uint256 supplyRate,
        uint256 borrowRate,
        uint256 utilization
    );

    /**
     * @notice Constructor for the mock lending pool
     * @param _asset The underlying asset token address
     * @param _name The name of the pool (e.g., "Pool A" or "Pool B")
     * @param _initialSupplyRate Initial supply rate in basis points
     * @param _initialBorrowRate Initial borrow rate in basis points
     * @param _initialUtilization Initial utilization rate in basis points
     */
    constructor(
        address _asset,
        string memory _name,
        uint256 _initialSupplyRate,
        uint256 _initialBorrowRate,
        uint256 _initialUtilization
    ) Ownable(msg.sender) {
        require(_asset != address(0), "Invalid asset address");
        asset = IERC20(_asset);
        name = _name;
        supplyRate = _initialSupplyRate;
        borrowRate = _initialBorrowRate;
        utilization = _initialUtilization;
    }

    /**
     * @notice Deposit assets into the lending pool
     * @param amount The amount of assets to deposit
     * @return shares The number of shares minted
     */
    function deposit(
        uint256 amount
    ) external override nonReentrant returns (uint256 shares) {
        require(amount >= MIN_DEPOSIT, "Deposit too small");

        // Calculate shares (1:1 for first deposit, then proportional)
        shares = convertToShares(amount);
        require(shares > 0, "Zero shares");

        // Transfer assets from user
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Update state
        totalAssets += amount;
        totalShares += shares;
        _shares[msg.sender] += shares;

        emit Deposit(msg.sender, amount, shares);
        emit LiquidityUpdated(totalAssets);
    }

    /**
     * @notice Withdraw assets from the lending pool
     * @param shares The number of shares to redeem
     * @return amount The amount of assets withdrawn
     */
    function withdraw(
        uint256 shares
    ) external override nonReentrant returns (uint256 amount) {
        require(shares > 0, "Zero shares");
        require(_shares[msg.sender] >= shares, "Insufficient shares");

        // Calculate assets
        amount = convertToAssets(shares);
        require(amount > 0, "Zero amount");
        require(totalAssets >= amount, "Insufficient liquidity");

        // Update state
        _shares[msg.sender] -= shares;
        totalShares -= shares;
        totalAssets -= amount;

        // Transfer assets to user
        asset.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, shares);
        emit LiquidityUpdated(totalAssets);
    }

    /**
     * @notice Convert shares to equivalent asset amount
     * @param shares The shares to convert
     * @return The equivalent asset amount
     */
    function convertToAssets(
        uint256 shares
    ) public view override returns (uint256) {
        if (totalShares == 0) return shares;
        return (shares * totalAssets) / totalShares;
    }

    /**
     * @notice Convert assets to equivalent shares amount
     * @param assets The assets to convert
     * @return The equivalent shares amount
     */
    function convertToShares(
        uint256 assets
    ) public view override returns (uint256) {
        if (totalAssets == 0 || totalShares == 0) return assets;
        return (assets * totalShares) / totalAssets;
    }

    /**
     * @notice Get shares balance of an account
     * @param account The account to query
     * @return The shares balance
     */
    function sharesOf(
        address account
    ) external view override returns (uint256) {
        return _shares[account];
    }

    /**
     * @notice Get current supply rate
     * @return The supply rate in basis points
     */
    function getSupplyRate() external view override returns (uint256) {
        return supplyRate;
    }

    /**
     * @notice Get current borrow rate
     * @return The borrow rate in basis points
     */
    function getBorrowRate() external view override returns (uint256) {
        return borrowRate;
    }

    /**
     * @notice Get current utilization rate
     * @return The utilization in basis points
     */
    function getUtilization() external view override returns (uint256) {
        return utilization;
    }

    // ===== Owner Functions =====

    /**
     * @notice Update the rates (simulates market conditions changing)
     * @dev This function emits the RateUpdated event that triggers the reactive contract
     * @param _supplyRate New supply rate in basis points
     * @param _borrowRate New borrow rate in basis points
     * @param _utilization New utilization rate in basis points
     */
    function updateRates(
        uint256 _supplyRate,
        uint256 _borrowRate,
        uint256 _utilization
    ) external {
        require(_supplyRate <= 10000, "Supply rate too high"); // Max 100%
        require(_borrowRate <= 10000, "Borrow rate too high"); // Max 100%
        require(_utilization <= 10000, "Utilization too high"); // Max 100%

        supplyRate = _supplyRate;
        borrowRate = _borrowRate;
        utilization = _utilization;

        // Emit the event that the Reactive Contract will listen to
        emit RateUpdated(supplyRate, borrowRate, block.timestamp);
        emit RatesManuallyUpdated(supplyRate, borrowRate, utilization);
    }

    /**
     * @notice Simulate yield accrual (increases totalAssets)
     * @param yieldAmount The amount of yield to add
     */
    function simulateYield(uint256 yieldAmount) external onlyOwner {
        totalAssets += yieldAmount;
    }

    /**
     * @notice Emergency withdrawal by owner
     * @param token The token to withdraw
     * @param amount The amount to withdraw
     * @param to The recipient address
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }
}
