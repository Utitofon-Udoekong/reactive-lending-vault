# Design Document: Cross-Chain Lending Automation Vault

## 1. Introduction

This document describes the design of a cross-chain lending automation vault that uses Reactive Smart Contracts to automatically rebalance funds between multiple lending pools based on yield optimization.

## 2. Problem Statement

### 2.1 The Challenge

DeFi users face a significant challenge: maximizing yield across multiple lending protocols requires constant monitoring and manual intervention. Rates change frequently based on:

- Market supply and demand
- Protocol utilization rates
- Incentive programs
- Market volatility

### 2.2 Current Solutions and Their Limitations

1. **Manual Rebalancing**: Time-consuming, error-prone, requires constant attention
2. **Centralized Aggregators**: Single points of failure, custody risks
3. **Keeper Networks**: Expensive, require ongoing fees, still somewhat centralized
4. **Yield Optimizers (e.g., Yearn)**: Complex strategies, smart contract risk, fees

### 2.3 Our Solution

A **trustless, on-chain automation system** using Reactive Smart Contracts that:
- Monitors yield rates across multiple pools in real-time
- Automatically rebalances when conditions are favorable
- Operates without any off-chain infrastructure
- Provides a simple vault interface for users

## 3. System Architecture

### 3.1 Components

#### 3.1.1 Origin Contracts (Ethereum Sepolia)

**MockLendingPool.sol**
- Simulates a lending pool with deposit/withdraw functionality
- Emits `RateUpdated` events when rates change
- Provides rate information (supply rate, borrow rate, utilization)

**MockToken.sol**
- ERC20 token for testing
- Includes faucet function for easy testing

#### 3.1.2 Destination Contract (Ethereum Sepolia)

**LendingVault.sol**
- Main user-facing contract
- Manages deposits and withdrawals
- Executes rebalancing logic when triggered
- Maintains accounting for user shares

#### 3.1.3 Reactive Contract (Reactive Network)

**YieldMonitorReactive.sol**
- Subscribes to `RateUpdated` events from both pools
- Stores latest rate information
- Evaluates rebalancing conditions
- Emits `Callback` events to trigger rebalancing

### 3.2 Data Flow

```
1. User deposits → LendingVault → Allocates to Pool A & B
2. Pool rate changes → RateUpdated event emitted
3. Reactive Network captures event → Calls react()
4. react() evaluates conditions → If threshold met, emit Callback
5. Reactive Network executes callback → LendingVault.executeRebalance()
6. Vault moves funds from lower-yield to higher-yield pool
```

## 4. Smart Contract Design

### 4.1 LendingVault

#### State Variables

```solidity
IERC20 public immutable asset;
ILendingPool public immutable poolA;
ILendingPool public immutable poolB;
address public authorizedReactVM;
uint256 public totalShares;
mapping(address => uint256) private _shares;
uint256 public rebalanceThreshold;
uint256 public rebalanceCooldown;
uint256 public lastRebalanceTime;
uint256 public rebalancePercentage;
```

#### Key Functions

- `deposit(amount)`: Deposit assets, receive shares, allocate to pools
- `withdraw(shares)`: Redeem shares, receive proportional assets
- `executeRebalance(rvmId)`: Called by Reactive callback to rebalance

#### Allocation Strategy

On deposit, funds are allocated based on current rates:
- 70% to the higher-yielding pool
- 30% to the lower-yielding pool

This provides:
- Immediate yield optimization
- Diversification across pools
- Buffer for rate changes

### 4.2 YieldMonitorReactive

#### Subscription Setup

```solidity
constructor(...) {
    service.subscribe(
        originChainId,
        poolA,
        REACTIVE_IGNORE,  // Any topic_0
        REACTIVE_IGNORE,
        REACTIVE_IGNORE,
        REACTIVE_IGNORE
    );
    // Similar for poolB
}
```

#### Event Processing

```solidity
function react(LogRecord calldata log) external vmOnly {
    // Update stored rate based on source
    if (log._contract == poolA) {
        lastRateA = log.topic_1;
    } else if (log._contract == poolB) {
        lastRateB = log.topic_1;
    }
    
    // Evaluate rebalance conditions
    _evaluateRebalance(log.block_number);
}
```

#### Rebalance Trigger

```solidity
function _evaluateRebalance(uint256 currentBlock) internal {
    // Check cooldown
    if (currentBlock < lastRebalanceBlock + minBlocksBetweenRebalance) return;
    
    // Check threshold
    uint256 rateDiff = abs(lastRateA - lastRateB);
    if (rateDiff < rebalanceThreshold) return;
    
    // Trigger rebalance
    bytes memory payload = abi.encodeWithSignature(
        "executeRebalance(address)",
        address(0)  // Replaced by ReactVM ID
    );
    emit Callback(destinationChainId, lendingVault, CALLBACK_GAS_LIMIT, payload);
}
```

## 5. Rebalancing Logic

### 5.1 Trigger Conditions

1. **Rate Difference Threshold**: Rate difference > 1% (configurable)
2. **Cooldown Period**: Last rebalance > 60 seconds ago
3. **Block Minimum**: Last rebalance > N blocks ago (Reactive side)

### 5.2 Rebalancing Algorithm

```
1. Identify higher-yield pool (target)
2. Identify lower-yield pool (source)
3. Calculate amount to move: source_value * rebalance_percentage
4. Withdraw from source pool
5. Deposit to target pool
6. Update last rebalance timestamp
```

### 5.3 Percentage-Based Approach

We move 50% of the source pool balance rather than 100% because:
- Reduces slippage risk
- Maintains diversification
- Handles rate volatility
- Multiple rebalances converge to optimal allocation

## 6. Economic Considerations

### 6.1 Gas Costs

| Operation | Estimated Gas |
|-----------|--------------|
| Vault Deposit | ~150,000 |
| Vault Withdraw | ~200,000 |
| Rebalance | ~300,000 |
| Reactive Callback | ~50,000 (Reactive) + ~300,000 (Sepolia) |

### 6.2 Fee Structure

For production deployment, consider:
- Management fee: 0.5-1% annual (to cover gas costs)
- Performance fee: 10-20% of yield above baseline
- No deposit/withdrawal fees

### 6.3 Break-Even Analysis

Rebalancing is profitable when:
```
Yield Improvement > Gas Cost / Time Period
```

For a $100,000 vault at current gas prices (~10 gwei):
- Rebalance cost: ~$1-2
- 1% rate improvement over 1 week: ~$19
- Net benefit: ~$17-18 per rebalance

## 7. Trade-offs

### 7.1 Simplicity vs. Optimization

**Chosen**: Simple percentage-based rebalancing
**Alternative**: Complex optimization with multiple factors

*Rationale*: Simpler code is more secure, easier to audit, and sufficient for the use case.

### 7.2 Gas Efficiency vs. Reactivity

**Chosen**: Block-based cooldown on Reactive side
**Alternative**: Time-based cooldown only

*Rationale*: Double protection prevents excessive callback costs during high volatility.

### 7.3 Centralization vs. Flexibility

**Chosen**: Single authorized ReactVM
**Alternative**: Multiple authorized callers

*Rationale*: Single source reduces attack surface; can be upgraded later if needed.

### 7.4 Allocation Strategy

**Chosen**: 70/30 split favoring higher yield
**Alternative**: 100% to highest yield

*Rationale*: Diversification protects against pool-specific risks and rate reversals.

## 8. Future Improvements

### 8.1 Short Term

- Support for more than 2 pools
- Dynamic threshold based on position size
- APY calculations including fees

### 8.2 Medium Term

- Cross-chain pools (actual cross-chain rebalancing)
- Leveraged yield strategies
- Integration with real lending protocols (Aave, Compound)

### 8.3 Long Term

- Machine learning for rate prediction
- Social yield strategies (copy trading)
- DAO governance for strategy parameters

## 9. Conclusion

This design provides a solid foundation for automated yield optimization using Reactive Smart Contracts. The architecture balances security, gas efficiency, and yield optimization while maintaining simplicity and auditability.

The use of Reactive Smart Contracts eliminates the need for off-chain infrastructure, making the system fully trustless and censorship-resistant. Users can deposit once and benefit from continuous yield optimization without any manual intervention.
