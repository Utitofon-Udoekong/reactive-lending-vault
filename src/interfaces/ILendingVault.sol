// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILendingVault
 * @notice Interface for the Cross-Chain Lending Vault
 * @dev Users interact with this interface to deposit/withdraw funds
 */
interface ILendingVault {
    /// @notice Emitted when user deposits into the vault
    event VaultDeposit(address indexed user, uint256 amount, uint256 shares);
    
    /// @notice Emitted when user withdraws from the vault
    event VaultWithdraw(address indexed user, uint256 amount, uint256 shares);
    
    /// @notice Emitted when funds are rebalanced between pools
    event Rebalance(
        address indexed fromPool,
        address indexed toPool,
        uint256 amount,
        uint256 poolARateNew,
        uint256 poolBRateNew
    );

    /// @notice Emitted when rebalance is triggered by reactive contract
    event RebalanceTriggered(
        address indexed caller,
        uint256 poolARate,
        uint256 poolBRate,
        uint256 rateDiff
    );

    /// @notice Deposit assets into the vault
    /// @param amount The amount to deposit
    /// @return shares The vault shares minted
    function deposit(uint256 amount) external returns (uint256 shares);

    /// @notice Withdraw assets from the vault
    /// @param shares The shares to redeem
    /// @return amount The amount withdrawn
    function withdraw(uint256 shares) external returns (uint256 amount);

    /// @notice Execute rebalance - called by reactive contract callback
    /// @param rvmId The ReactVM ID (automatically injected)
    function executeRebalance(address rvmId) external;

    /// @notice Get total assets managed by vault
    function totalAssets() external view returns (uint256);

    /// @notice Get total vault shares
    function totalShares() external view returns (uint256);

    /// @notice Get shares of an account
    function sharesOf(address account) external view returns (uint256);

    /// @notice Get current allocation ratios
    function getAllocation() external view returns (uint256 poolAAlloc, uint256 poolBAlloc);

    /// @notice Get pool addresses
    function getPoolAddresses() external view returns (address poolA, address poolB);
}
