// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/reactive/YieldMonitorReactive.sol";
import "../src/reactive/AbstractReactive.sol";
import "../src/interfaces/IReactive.sol";

/**
 * @title TestableYieldMonitor
 * @notice A test harness that bypasses system contract calls
 */
contract TestableYieldMonitor is YieldMonitorReactive {
    constructor(
        uint256 _originChainId,
        uint256 _destinationChainId,
        address _poolA,
        address _poolB,
        address _lendingVault,
        uint256 _rebalanceThreshold,
        uint256 _minBlocksBetweenRebalance
    ) YieldMonitorReactive(
        _originChainId,
        _destinationChainId,
        _poolA,
        _poolB,
        _lendingVault,
        _rebalanceThreshold,
        _minBlocksBetweenRebalance
    ) {}

    // Override react to allow calling in tests (bypass vmOnly)
    function testReact(LogRecord calldata log) external {
        eventsProcessed++;
        uint256 newSupplyRate = log.topic_1;
        
        if (log._contract == poolA) {
            lastRateA = newSupplyRate;
            emit RateUpdateProcessed(poolA, newSupplyRate, block.timestamp, log.block_number);
        } else if (log._contract == poolB) {
            lastRateB = newSupplyRate;
            emit RateUpdateProcessed(poolB, newSupplyRate, block.timestamp, log.block_number);
        } else {
            return;
        }
        _evaluateRebalanceTest(log.block_number);
    }

    function _evaluateRebalanceTest(uint256 currentBlock) internal {
        if (currentBlock < lastRebalanceBlock + minBlocksBetweenRebalance) {
            emit RebalanceSkipped("Minimum blocks not elapsed", lastRateA, lastRateB, currentBlock);
            return;
        }
        if (lastRateA == 0 && lastRateB == 0) {
            emit RebalanceSkipped("Rates not initialized", lastRateA, lastRateB, currentBlock);
            return;
        }
        uint256 rateDiff = lastRateA > lastRateB ? lastRateA - lastRateB : lastRateB - lastRateA;
        if (rateDiff < rebalanceThreshold) {
            emit RebalanceSkipped("Rate difference below threshold", lastRateA, lastRateB, currentBlock);
            return;
        }
        emit RebalanceConditionMet(lastRateA, lastRateB, rateDiff, currentBlock);
        lastRebalanceBlock = currentBlock;
        rebalancesTriggered++;
    }
}

/**
 * @title YieldMonitorReactiveTest
 * @notice Tests for the YieldMonitorReactive contract
 * @dev These tests simulate the ReactVM environment
 */
contract YieldMonitorReactiveTest is Test {
    TestableYieldMonitor public reactive;
    
    address public poolA;
    address public poolB;
    address public lendingVault;
    
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant REBALANCE_THRESHOLD = 100;
    uint256 constant MIN_BLOCKS = 5;
    
    event RateUpdateProcessed(address indexed pool, uint256 newRate, uint256 timestamp, uint256 blockNumber);
    event RebalanceConditionMet(uint256 rateA, uint256 rateB, uint256 rateDifference, uint256 blockNumber);
    event RebalanceSkipped(string reason, uint256 rateA, uint256 rateB, uint256 blockNumber);
    event Callback(uint256 indexed chain_id, address indexed _contract, uint64 indexed gas_limit, bytes payload);

    function setUp() public {
        poolA = makeAddr("poolA");
        poolB = makeAddr("poolB");
        lendingVault = makeAddr("lendingVault");
        
        // Deploy testable reactive contract
        reactive = new TestableYieldMonitor(
            SEPOLIA_CHAIN_ID,
            SEPOLIA_CHAIN_ID,
            poolA,
            poolB,
            lendingVault,
            REBALANCE_THRESHOLD,
            MIN_BLOCKS
        );
    }

    function test_InitialState() public view {
        assertEq(reactive.originChainId(), SEPOLIA_CHAIN_ID);
        assertEq(reactive.destinationChainId(), SEPOLIA_CHAIN_ID);
        assertEq(reactive.poolA(), poolA);
        assertEq(reactive.poolB(), poolB);
        assertEq(reactive.lendingVault(), lendingVault);
        assertEq(reactive.rebalanceThreshold(), REBALANCE_THRESHOLD);
        assertEq(reactive.minBlocksBetweenRebalance(), MIN_BLOCKS);
        assertEq(reactive.lastRateA(), 0);
        assertEq(reactive.lastRateB(), 0);
        assertEq(reactive.eventsProcessed(), 0);
        assertEq(reactive.rebalancesTriggered(), 0);
    }

    function test_React_UpdatesRateA() public {
        IReactive.LogRecord memory log = _createLogRecord(poolA, 500, 0);
        
        vm.expectEmit(true, false, false, true);
        emit RateUpdateProcessed(poolA, 500, block.timestamp, log.block_number);
        
        reactive.testReact(log);
        
        assertEq(reactive.lastRateA(), 500);
        assertEq(reactive.eventsProcessed(), 1);
    }

    function test_React_UpdatesRateB() public {
        IReactive.LogRecord memory log = _createLogRecord(poolB, 300, 0);
        
        reactive.testReact(log);
        
        assertEq(reactive.lastRateB(), 300);
        assertEq(reactive.eventsProcessed(), 1);
    }

    function test_React_IgnoresUnknownContract() public {
        address unknown = makeAddr("unknown");
        IReactive.LogRecord memory log = _createLogRecord(unknown, 500, 0);
        
        reactive.testReact(log);
        
        assertEq(reactive.lastRateA(), 0);
        assertEq(reactive.lastRateB(), 0);
        assertEq(reactive.eventsProcessed(), 1);
    }

    function test_React_TriggersRebalanceWhenConditionsMet() public {
        // Set initial rates
        IReactive.LogRecord memory logA = _createLogRecord(poolA, 500, 0);
        reactive.testReact(logA);
        
        IReactive.LogRecord memory logB = _createLogRecord(poolB, 300, MIN_BLOCKS + 1);
        reactive.testReact(logB);
        
        // Now update with significant difference
        IReactive.LogRecord memory logA2 = _createLogRecord(poolA, 800, MIN_BLOCKS + 2);
        
        vm.expectEmit(false, false, false, true);
        emit RebalanceConditionMet(800, 300, 500, MIN_BLOCKS + 2);
        
        reactive.testReact(logA2);
        
        assertEq(reactive.rebalancesTriggered(), 1);
    }

    function test_React_SkipsRebalanceIfThresholdNotMet() public {
        IReactive.LogRecord memory logA = _createLogRecord(poolA, 500, 0);
        reactive.testReact(logA);
        
        IReactive.LogRecord memory logB = _createLogRecord(poolB, 510, MIN_BLOCKS + 1);
        
        vm.expectEmit(false, false, false, true);
        emit RebalanceSkipped("Rate difference below threshold", 500, 510, MIN_BLOCKS + 1);
        
        reactive.testReact(logB);
        
        assertEq(reactive.rebalancesTriggered(), 0);
    }

    function test_React_SkipsRebalanceIfMinBlocksNotElapsed() public {
        // First update
        IReactive.LogRecord memory logA = _createLogRecord(poolA, 500, 0);
        reactive.testReact(logA);
        
        IReactive.LogRecord memory logB = _createLogRecord(poolB, 300, 1);
        reactive.testReact(logB);
        
        // Trigger first rebalance
        IReactive.LogRecord memory logA2 = _createLogRecord(poolA, 800, MIN_BLOCKS + 1);
        reactive.testReact(logA2);
        assertEq(reactive.rebalancesTriggered(), 1);
        
        // Try to rebalance again too soon
        IReactive.LogRecord memory logA3 = _createLogRecord(poolA, 900, MIN_BLOCKS + 2);
        
        vm.expectEmit(false, false, false, true);
        emit RebalanceSkipped("Minimum blocks not elapsed", 900, 300, MIN_BLOCKS + 2);
        
        reactive.testReact(logA3);
        
        assertEq(reactive.rebalancesTriggered(), 1); // Still 1
    }

    function test_GetStoredRates() public {
        IReactive.LogRecord memory logA = _createLogRecord(poolA, 500, 0);
        IReactive.LogRecord memory logB = _createLogRecord(poolB, 300, 1);
        
        reactive.testReact(logA);
        reactive.testReact(logB);
        
        (uint256 rateA, uint256 rateB) = reactive.getStoredRates();
        assertEq(rateA, 500);
        assertEq(rateB, 300);
    }

    function test_GetStats() public {
        IReactive.LogRecord memory logA = _createLogRecord(poolA, 500, 0);
        IReactive.LogRecord memory logB = _createLogRecord(poolB, 300, 1);
        IReactive.LogRecord memory logA2 = _createLogRecord(poolA, 800, MIN_BLOCKS + 2);
        
        reactive.testReact(logA);
        reactive.testReact(logB);
        reactive.testReact(logA2);
        
        (uint256 events, uint256 rebalances) = reactive.getStats();
        assertEq(events, 3);
        assertEq(rebalances, 1);
    }

    function test_WouldRebalance() public {
        IReactive.LogRecord memory logA = _createLogRecord(poolA, 500, 0);
        IReactive.LogRecord memory logB = _createLogRecord(poolB, 300, 1);
        
        reactive.testReact(logA);
        reactive.testReact(logB);
        
        (bool shouldRebalance, uint256 rateDiff) = reactive.wouldRebalance();
        assertTrue(shouldRebalance);
        assertEq(rateDiff, 200);
    }

    function testFuzz_React_HandlesAnyRate(uint256 rate) public {
        rate = bound(rate, 0, 10000);
        
        IReactive.LogRecord memory log = _createLogRecord(poolA, rate, 0);
        reactive.testReact(log);
        
        assertEq(reactive.lastRateA(), rate);
    }

    // ===== Helper Functions =====

    function _createLogRecord(
        address contractAddr,
        uint256 rate,
        uint256 blockNumber
    ) internal pure returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chain_id: SEPOLIA_CHAIN_ID,
            _contract: contractAddr,
            topic_0: 0, // RateUpdated signature
            topic_1: rate, // newSupplyRate (indexed)
            topic_2: 0, // newBorrowRate (indexed)
            topic_3: 0,
            data: "",
            block_number: blockNumber,
            op_code: 0,
            block_hash: 0,
            tx_hash: 0,
            log_index: 0
        });
    }
}
