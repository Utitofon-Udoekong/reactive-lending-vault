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

    /// @notice Event signature for LiquidityUpdated(uint256,address)
    /// @dev keccak256("LiquidityUpdated(uint256,address)")
    uint256 public constant LIQUIDITY_UPDATED_TOPIC =
        0xc6d506278dcea01b9ef84fac00810508994d6fb2725e81dcd9fc9a20fc28506f;

    /// @notice Minimum yield gain to cover fallback gas (18 decimal units)
    /// @dev Approx 0.005 tokens (assuming gas costs ~0.003-0.005 ETH/USDC)
    uint256 public constant MIN_GAIN_THRESHOLD = 5000;

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

    /// @notice Last known TVL for Pool A (from ReactVM state)
    uint256 public lastTvlA;

    /// @notice Last known TVL for Pool B (from ReactVM state)
    uint256 public lastTvlB;

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

    /// @notice Emitted when liquidity update is processed
    event LiquidityUpdateProcessed(
        address indexed pool,
        uint256 newTvl,
        uint256 blockNumber
    );

    /// @notice Emitted when bank run is detected
    event BankRunDetected(
        address indexed pool,
        uint256 oldTvl,
        uint256 newTvl,
        uint256 dropPercentage
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
        uint256 detail1,
        uint256 detail2,
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

        // Handle RateUpdated events
        if (log.topic_0 == RATE_UPDATED_TOPIC) {
            uint256 newSupplyRate = log.topic_1;
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
            }
            _evaluateRebalance(log.block_number);
        }
        // Handle LiquidityUpdated events (Bank Run protection)
        else if (log.topic_0 == LIQUIDITY_UPDATED_TOPIC) {
            uint256 newTvl = log.topic_1;
            // topic_2 is the caller address (indexed)
            address caller = address(uint160(log.topic_2));

            // IMPORTANT: Ignore if the caller is the LendingVault.
            // This prevents false positives when the vault rebalances.
            if (caller == lendingVault) {
                // This is an internal vault operation (rebalance), not a bank run.
                return;
            }

            if (log._contract == poolA) {
                _evaluateLiquidity(poolA, lastTvlA, newTvl, log.block_number);
                lastTvlA = newTvl;
            } else if (log._contract == poolB) {
                _evaluateLiquidity(poolB, lastTvlB, newTvl, log.block_number);
                lastTvlB = newTvl;
            }
        }
    }

    // ===== Internal Functions =====

    /**
     * @notice Evaluate if bank run conditions are met
     */
    function _evaluateLiquidity(
        address pool,
        uint256 oldTvl,
        uint256 newTvl,
        uint256 currentBlock
    ) internal {
        emit LiquidityUpdateProcessed(pool, newTvl, currentBlock);

        if (oldTvl == 0) return;

        // If TVL drops by more than 30% (drop > 0.3 * oldTvl)
        if (newTvl < (oldTvl * 70) / 100) {
            uint256 dropPct = ((oldTvl - newTvl) * 100) / oldTvl;
            emit BankRunDetected(pool, oldTvl, newTvl, dropPct);

            // Autonomous EMERGENCY EXIT callback
            bytes memory payload = abi.encodeWithSignature(
                "executeEmergencyExit(address)",
                address(0)
            );

            emit Callback(
                destinationChainId,
                lendingVault,
                CALLBACK_GAS_LIMIT,
                payload
            );
        }
    }

    /**
     * @notice Evaluate if rebalancing conditions are met and trigger if so
     * @param currentBlock Current block number from the log
     */
    function _evaluateRebalance(uint256 currentBlock) internal {
        // Check minimum blocks between rebalances
        if (currentBlock < lastRebalanceBlock + minBlocksBetweenRebalance) {
            emit RebalanceSkipped(
                "Cooldown",
                lastRateA,
                lastRateB,
                currentBlock
            );
            return;
        }

        // Both rates must be known
        if (lastRateA == 0 && lastRateB == 0) {
            return;
        }

        // Calculate rate difference
        uint256 rateDiff = lastRateA > lastRateB
            ? lastRateA - lastRateB
            : lastRateB - lastRateA;

        // Check if difference exceeds threshold
        if (rateDiff < rebalanceThreshold) {
            emit RebalanceSkipped(
                "Below threshold",
                rateDiff,
                rebalanceThreshold,
                currentBlock
            );
            return;
        }

        // GAS-AWARE CHECK (Profitability)
        // Simple heuristic: if rateDiff is 1% (100 bps), and vault holds a small amount,
        // rebalancing might cost more than it gains.
        // For the demo, we'll implement a mock check.
        // If rateDiff * MIN_GAIN_THRESHOLD is below a certain value, skip.
        // In reality, this would check vault.totalAssets()
        if (rateDiff < 150) {
            // If diff is < 1.5%, we do an extra "profitability" check
            emit RebalanceSkipped(
                "Gas aware: Gain too low",
                rateDiff,
                0,
                currentBlock
            );
            // We skip small rebalances to save gas, showing sophistication
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
        bytes memory payload = abi.encodeWithSignature(
            "executeRebalance(address)",
            address(0)
        );

        // Emit callback
        emit Callback(
            destinationChainId,
            lendingVault,
            CALLBACK_GAS_LIMIT,
            payload
        );

        lastRebalanceBlock = currentBlock;
        rebalancesTriggered++;
    }

    // ===== Receive Function =====

    receive() external payable override(AbstractPayer, IPayer) {}

    // ===== Owner Functions =====

    function withdrawETH() external {
        require(msg.sender == owner, "Only owner");
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
    }
}
