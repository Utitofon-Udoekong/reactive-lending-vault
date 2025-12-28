// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ISystemContract.sol";
import "../interfaces/IReactive.sol";

/**
 * @title AbstractReactive
 * @notice Base contract for Reactive Smart Contracts
 * @dev Provides common functionality for reactive contracts
 */
abstract contract AbstractReactive is IReactive {
    /// @notice Value used to ignore a topic filter
    uint256 internal constant REACTIVE_IGNORE = 
        0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    /// @notice Address of the Reactive Network system contract
    address internal constant SYSTEM_CONTRACT = 
        0x0000000000000000000000000000000000FFFFFF;

    /// @notice Reference to the system contract
    ISystemContract internal service;

    /// @notice Flag to detect if we're running in ReactVM or on Reactive Network
    bool internal vm;

    /// @notice Initialize the reactive contract
    constructor() {
        // Check if we're in ReactVM (system contract won't exist there)
        (bool success,) = SYSTEM_CONTRACT.call(abi.encodeWithSignature("ping()"));
        vm = !success;
        
        if (!vm) {
            service = ISystemContract(payable(SYSTEM_CONTRACT));
        }
    }

    /// @notice Modifier to ensure function only runs in ReactVM
    modifier vmOnly() {
        require(vm, "Only callable from ReactVM");
        _;
    }

    /// @notice Modifier to ensure function only runs on Reactive Network
    modifier rnOnly() {
        require(!vm, "Only callable from Reactive Network");
        _;
    }
}
