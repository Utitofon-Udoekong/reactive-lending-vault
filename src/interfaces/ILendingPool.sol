// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILendingPool
 * @notice Interface for lending pool interactions
 * @dev Both Pool A and Pool B implement this interface
 */
interface ILendingPool {
    /// @notice Emitted when supply rate is updated
    event RateUpdated(uint256 indexed newSupplyRate, uint256 indexed newBorrowRate, uint256 timestamp);
    
    /// @notice Emitted when a deposit is made
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    
    /// @notice Emitted when a withdrawal is made
    event Withdraw(address indexed user, uint256 amount, uint256 shares);

    /// @notice Deposit funds into the lending pool
    /// @param amount The amount to deposit
    /// @return shares The number of shares minted
    function deposit(uint256 amount) external returns (uint256 shares);

    /// @notice Withdraw funds from the lending pool
    /// @param shares The number of shares to redeem
    /// @return amount The amount withdrawn
    function withdraw(uint256 shares) external returns (uint256 amount);

    /// @notice Get the current supply APY (in basis points, e.g., 500 = 5%)
    /// @return The current supply rate
    function getSupplyRate() external view returns (uint256);

    /// @notice Get the current borrow rate (in basis points)
    /// @return The current borrow rate
    function getBorrowRate() external view returns (uint256);

    /// @notice Get the current utilization rate (in basis points)
    /// @return The utilization rate
    function getUtilization() external view returns (uint256);

    /// @notice Get total assets in the pool
    /// @return Total assets
    function totalAssets() external view returns (uint256);

    /// @notice Get total shares minted
    /// @return Total shares
    function totalShares() external view returns (uint256);

    /// @notice Get shares balance of an account
    /// @param account The account to query
    /// @return The shares balance
    function sharesOf(address account) external view returns (uint256);

    /// @notice Convert shares to assets
    /// @param shares The shares amount
    /// @return The equivalent asset amount
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Convert assets to shares
    /// @param assets The asset amount
    /// @return The equivalent shares amount
    function convertToShares(uint256 assets) external view returns (uint256);
}
