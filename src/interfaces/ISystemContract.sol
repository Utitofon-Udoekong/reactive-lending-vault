// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISystemContract
 * @notice Interface for the Reactive Network System Contract
 * @dev Used to subscribe/unsubscribe to events on origin chains
 */
interface ISystemContract {
    /// @notice Subscribe to events matching the specified criteria
    /// @param chainId The chain ID to listen to
    /// @param contractAddr The contract address to filter (0 for any)
    /// @param topic0 Topic 0 filter (use REACTIVE_IGNORE for any)
    /// @param topic1 Topic 1 filter (use REACTIVE_IGNORE for any)
    /// @param topic2 Topic 2 filter (use REACTIVE_IGNORE for any)
    /// @param topic3 Topic 3 filter (use REACTIVE_IGNORE for any)
    function subscribe(
        uint256 chainId,
        address contractAddr,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) external;

    /// @notice Unsubscribe from events matching the specified criteria
    function unsubscribe(
        uint256 chainId,
        address contractAddr,
        uint256 topic0,
        uint256 topic1,
        uint256 topic2,
        uint256 topic3
    ) external;
}
