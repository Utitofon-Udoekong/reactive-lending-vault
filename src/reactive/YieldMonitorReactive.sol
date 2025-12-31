// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Use official reactive-lib instead of custom implementation
import "reactive-lib/abstract-base/AbstractReactive.sol";
import "../interfaces/ILendingPool.sol";

/**
 * @title YieldMonitorReactive
 * @notice Reactive Smart Contract for Cross-Chain Lending Vault Automation
 * @dev This contract monitors RateUpdated events from lending pools and triggers
 *      rebalancing when yield conditions warrant it.
 *
 * Architecture:
 * - Deployed on Reactive Network (Lasna Testnet or Mainnet)
 * - Subscribes to RateUpdated events from Pool A and Pool B on origin chain
 * - When rates change, evaluates if rebalancing is beneficial
 * - Emits Callback event to trigger executeRebalance() on destination vault
 *
 * How it works:
 * 1. Pool A or Pool B emits RateUpdated event when rates change
 * 2. Reactive Network captures the event and calls react() on this contract
 * 3. react() stores latest rates and checks if rebalance conditions are met
 * 4. If conditions met, emits Callback event with executeRebalance payload
 * 5. Reactive Network executes the callback on the destination vault
 */
contract YieldMonitorReactive is AbstractReactive {
    // ===== Constants =====

    /// @notice Event signature for RateUpdated(uint256,uint256,uint256)
    /// @dev keccak256("RateUpdated(uint256,uint256,uint256)")
    uint256 public constant RATE_UPDATED_TOPIC =
        0xa387c3601f61e88a17e341cfebf7ab826a8cd4544cd72b2dc0cf12988e77754b;

    /// @notice Gas limit for callback transactions
    uint64 public constant CALLBACK_GAS_LIMIT = 1000000;

    // ===== State Variables =====

    /// @notice Origin chain ID (e.g., Sepolia = 11155111)
    uint256 public immutable originChainId;

    /// @notice Destination chain ID (same as origin for this demo)
    uint256 public immutable destinationChainId;

    /// @notice Pool A address on origin chain
    address public immutable poolA;

    /// @notice Pool B address on origin chain
    address public immutable poolB;

    /// @notice Lending vault address on destination chain
    address public immutable lendingVault;

    /// @notice Minimum rate difference threshold (basis points)
    uint256 public rebalanceThreshold;

    /// @notice Minimum blocks between rebalances
    uint256 public minBlocksBetweenRebalance;

    /// @notice Last block when rebalance was triggered
    uint256 public lastRebalanceBlock;

    /// @notice Last known rate for Pool A (from ReactVM state)
    uint256 public lastRateA;

    /// @notice Last known rate for Pool B (from ReactVM state)
    uint256 public lastRateB;

    /// @notice Counter for events processed
    uint256 public eventsProcessed;

    /// @notice Counter for rebalances triggered
    uint256 public rebalancesTriggered;

    /// @notice Contract owner (deployer) for emergency withdrawals
    address public immutable owner;

    // ===== Events =====

    /// @notice Emitted when rate update is processed
    event RateUpdateProcessed(
        address indexed pool,
        uint256 newRate,
        uint256 timestamp,
        uint256 blockNumber
    );

    /// @notice Emitted when rebalance is triggered
    event RebalanceConditionMet(
        uint256 rateA,
        uint256 rateB,
        uint256 rateDifference,
        uint256 blockNumber
    );

    /// @notice Emitted when rebalance is skipped
    event RebalanceSkipped(
        string reason,
        uint256 rateA,
        uint256 rateB,
        uint256 blockNumber
    );

    // ===== Constructor =====

    /**
     * @notice Initialize the Reactive Contract
     * @param _originChainId Chain ID of the origin chain (e.g., Sepolia)
     * @param _destinationChainId Chain ID of the destination chain
     * @param _poolA Address of Pool A on origin chain
     * @param _poolB Address of Pool B on origin chain
     * @param _lendingVault Address of the lending vault on destination chain
     * @param _rebalanceThreshold Minimum rate difference to trigger rebalance (bps)
     * @param _minBlocksBetweenRebalance Minimum blocks between rebalances
     */
    constructor(
        uint256 _originChainId,
        uint256 _destinationChainId,
        address _poolA,
        address _poolB,
        address _lendingVault,
        uint256 _rebalanceThreshold,
        uint256 _minBlocksBetweenRebalance
    ) payable {
        require(_poolA != address(0), "Invalid pool A");
        require(_poolB != address(0), "Invalid pool B");
        require(_lendingVault != address(0), "Invalid vault");

        originChainId = _originChainId;
        destinationChainId = _destinationChainId;
        poolA = _poolA;
        poolB = _poolB;
        lendingVault = _lendingVault;
        rebalanceThreshold = _rebalanceThreshold;
        minBlocksBetweenRebalance = _minBlocksBetweenRebalance;
        owner = msg.sender;

        // Note: Subscriptions are set up separately via setupSubscriptions()
        // This avoids constructor failures on Reactive Network
    }

    /// @notice Set up event subscriptions (call after deployment on Reactive Network)
    /// @dev Only callable by owner, only on Reactive Network (not in ReactVM)
    function setupSubscriptions() external rnOnly {
        require(msg.sender == owner, "Only owner");

        // Subscribe to all events from Pool A
        service.subscribe(
            originChainId,
            poolA,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );

        // Subscribe to all events from Pool B
        service.subscribe(
            originChainId,
            poolB,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    // ===== React Function =====

    /**
     * @notice Process incoming events from subscribed pools
     * @dev Called by ReactVM when matching events are detected
     * @param log The log record containing event data
     */
    function react(LogRecord calldata log) external override vmOnly {
        eventsProcessed++;

        // IMPORTANT: Only process RateUpdated events
        // updateRates() emits TWO events: RateUpdated and RatesManuallyUpdated
        // RatesManuallyUpdated has non-indexed params, so topic_1 would be 0
        // which would overwrite our stored rate incorrectly
        if (log.topic_0 != RATE_UPDATED_TOPIC) {
            return; // Skip non-RateUpdated events
        }

        // Parse the rate from the event
        // RateUpdated(uint256 newSupplyRate, uint256 newBorrowRate, uint256 timestamp)
        // topic_1 = newSupplyRate (indexed)
        // topic_2 = newBorrowRate (indexed)
        uint256 newSupplyRate = log.topic_1;

        // Update stored rates based on which pool emitted the event
        if (log._contract == poolA) {
            lastRateA = newSupplyRate;
            emit RateUpdateProcessed(
                poolA,
                newSupplyRate,
                block.timestamp,
                log.block_number
            );
        } else if (log._contract == poolB) {
            lastRateB = newSupplyRate;
            emit RateUpdateProcessed(
                poolB,
                newSupplyRate,
                block.timestamp,
                log.block_number
            );
        } else {
            // Unknown contract, skip
            return;
        }

        // Check if we should trigger rebalance
        _evaluateRebalance(log.block_number);
    }

    // ===== Internal Functions =====

    /**
     * @notice Evaluate if rebalancing conditions are met and trigger if so
     * @param currentBlock Current block number from the log
     */
    function _evaluateRebalance(uint256 currentBlock) internal {
        // Check minimum blocks between rebalances
        if (currentBlock < lastRebalanceBlock + minBlocksBetweenRebalance) {
            emit RebalanceSkipped(
                "Minimum blocks not elapsed",
                lastRateA,
                lastRateB,
                currentBlock
            );
            return;
        }

        // Both rates must be known
        if (lastRateA == 0 && lastRateB == 0) {
            emit RebalanceSkipped(
                "Rates not initialized",
                lastRateA,
                lastRateB,
                currentBlock
            );
            return;
        }

        // Calculate rate difference
        uint256 rateDiff = lastRateA > lastRateB
            ? lastRateA - lastRateB
            : lastRateB - lastRateA;

        // Check if difference exceeds threshold
        if (rateDiff < rebalanceThreshold) {
            emit RebalanceSkipped(
                "Rate difference below threshold",
                lastRateA,
                lastRateB,
                currentBlock
            );
            return;
        }

        // Conditions met - trigger rebalance!
        emit RebalanceConditionMet(
            lastRateA,
            lastRateB,
            rateDiff,
            currentBlock
        );

        // Build callback payload for executeRebalance(address rvmId)
        // The first argument (address(0)) will be replaced by ReactVM ID
        bytes memory payload = abi.encodeWithSignature(
            "executeRebalance(address)",
            address(0) // Will be replaced with ReactVM ID by Reactive Network
        );

        // Emit callback to trigger transaction on destination chain
        emit Callback(
            destinationChainId,
            lendingVault,
            CALLBACK_GAS_LIMIT,
            payload
        );

        // Update state
        lastRebalanceBlock = currentBlock;
        rebalancesTriggered++;
    }

    // ===== View Functions =====

    /**
     * @notice Get current stored rates
     * @return rateA Last known rate from Pool A
     * @return rateB Last known rate from Pool B
     */
    function getStoredRates()
        external
        view
        returns (uint256 rateA, uint256 rateB)
    {
        return (lastRateA, lastRateB);
    }

    /**
     * @notice Get statistics
     * @return _eventsProcessed Total events processed
     * @return _rebalancesTriggered Total rebalances triggered
     */
    function getStats()
        external
        view
        returns (uint256 _eventsProcessed, uint256 _rebalancesTriggered)
    {
        return (eventsProcessed, rebalancesTriggered);
    }

    /**
     * @notice Check if rebalance would be triggered with current stored rates
     * @return shouldRebalance Whether rebalance conditions are met
     * @return rateDiff The current rate difference
     */
    function wouldRebalance()
        external
        view
        returns (bool shouldRebalance, uint256 rateDiff)
    {
        rateDiff = lastRateA > lastRateB
            ? lastRateA - lastRateB
            : lastRateB - lastRateA;
        shouldRebalance = rateDiff >= rebalanceThreshold;
    }

    // ===== Receive Function =====

    /// @notice Accept ETH for callback payments
    receive() external payable override(AbstractPayer, IPayer) {}

    // ===== Owner Functions =====

    /// @notice Withdraw ETH from contract (owner only)
    /// @dev Used to recover funds if contract is no longer needed
    function withdrawETH() external {
        require(msg.sender == owner, "Only owner");
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner).transfer(balance);
    }
}
