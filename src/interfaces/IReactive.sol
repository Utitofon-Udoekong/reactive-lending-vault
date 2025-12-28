// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IReactive
 * @notice Interface for Reactive Smart Contracts
 * @dev Reactive contracts must implement this interface to receive events from the Reactive Network
 */
interface IReactive {
    /// @notice Log record structure passed to reactive contracts
    struct LogRecord {
        uint256 chain_id;
        address _contract;
        uint256 topic_0;
        uint256 topic_1;
        uint256 topic_2;
        uint256 topic_3;
        bytes data;
        uint256 block_number;
        uint256 op_code;
        uint256 block_hash;
        uint256 tx_hash;
        uint256 log_index;
    }

    /// @notice Callback event to trigger transactions on destination chains
    event Callback(
        uint256 indexed chain_id,
        address indexed _contract,
        uint64 indexed gas_limit,
        bytes payload
    );

    /// @notice React to incoming events
    /// @param log The log record to process
    function react(LogRecord calldata log) external;
}
