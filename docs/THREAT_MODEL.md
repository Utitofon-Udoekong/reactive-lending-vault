# Threat Model: Cross-Chain Lending Automation Vault

## 1. Executive Summary

This document analyzes potential security threats to the Cross-Chain Lending Automation Vault and describes the mitigations implemented.

## 2. Assets at Risk

| Asset | Value | Description |
|-------|-------|-------------|
| User Deposits | High | ERC20 tokens deposited in the vault |
| Vault Shares | High | Represent ownership of pool positions |
| Pool Positions | High | Shares in lending pools A and B |
| Callback Funds | Medium | REACT tokens for callback execution |
| Contract Control | High | Owner privileges and configuration |

## 3. Threat Analysis

### 3.1 Smart Contract Vulnerabilities

#### 3.1.1 Reentrancy Attacks

**Threat**: Attacker exploits callback during state changes to drain funds.

**Severity**: Critical

**Mitigations**:
- All external functions use `nonReentrant` modifier
- State changes occur before external calls
- OpenZeppelin's ReentrancyGuard implementation

```solidity
function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
    // State changes first
    _shares[msg.sender] -= shares;
    totalShares -= shares;
    
    // Then external calls
    _withdrawFromPools(amount);
    asset.safeTransfer(msg.sender, amount);
}
```

#### 3.1.2 Integer Overflow/Underflow

**Threat**: Arithmetic operations overflow/underflow causing incorrect calculations.

**Severity**: High

**Mitigations**:
- Solidity 0.8.x with built-in overflow protection
- Explicit bounds checking in critical functions
- Use of SafeERC20 for token operations

#### 3.1.3 Access Control Bypass

**Threat**: Unauthorized parties execute privileged functions.

**Severity**: Critical

**Mitigations**:
- `onlyOwner` modifier for admin functions
- `authorizedReactVM` check for rebalance execution
- ReactVM ID verification in callbacks

```solidity
function executeRebalance(address rvmId) external nonReentrant {
    require(rvmId == authorizedReactVM, "Unauthorized ReactVM");
    // ...
}
```

### 3.2 Economic Attacks

#### 3.2.1 Rate Manipulation

**Threat**: Attacker manipulates pool rates to trigger advantageous rebalances.

**Severity**: High

**Attack Vector**:
1. Flash loan large amount
2. Manipulate pool utilization to change rates
3. Trigger rebalance
4. Reverse manipulation
5. Profit from misallocated funds

**Mitigations**:
- Cooldown period between rebalances (60 seconds)
- Minimum block delay (5 blocks)
- Threshold requirement prevents micro-manipulation
- Percentage-based rebalancing (not 100%)

**Residual Risk**: Medium - Flash loan attacks still possible but limited by:
- Cost of attack > potential profit for most scenarios
- Rate changes require actual deposits/withdrawals

#### 3.2.2 Sandwich Attacks

**Threat**: MEV bots sandwich rebalance transactions.

**Severity**: Medium

**Mitigations**:
- Internal pool operations (less exposed to mempool)
- No swaps or DEX interactions
- Rebalance amount limited to 50%

#### 3.2.3 Griefing via Repeated Rate Changes

**Threat**: Attacker spams rate changes to drain callback funds.

**Severity**: Low

**Mitigations**:
- Block-based cooldown on Reactive side
- Threshold requirement filters minor changes
- Only pool owners can update rates (in mock implementation)

### 3.3 Cross-Chain Risks

#### 3.3.1 ReactVM ID Spoofing

**Threat**: Attacker calls executeRebalance with fake ReactVM ID.

**Severity**: Critical

**Mitigations**:
- Reactive Network replaces first 160 bits with actual ReactVM ID
- Cannot be spoofed after contract deployment
- Verified through `authorizedReactVM` check

#### 3.3.2 Callback Replay

**Threat**: Replay old callback transactions.

**Severity**: Medium

**Mitigations**:
- Each callback is a unique transaction
- Cooldown prevents rapid successive calls
- Rate conditions must still be met

#### 3.3.3 Reactive Network Failure

**Threat**: Reactive Network goes offline, callbacks stop.

**Severity**: Medium

**Impact**: No automatic rebalancing, but funds remain safe

**Mitigations**:
- Funds are always in user custody (vault controls)
- Emergency exit functions allow manual recovery
- Users can withdraw at any time

### 3.4 Operational Risks

#### 3.4.1 Key Compromise

**Threat**: Owner private key is compromised.

**Severity**: Critical

**Impact**: 
- Can change authorized ReactVM
- Can modify rebalancing parameters
- Can call emergency functions

**Mitigations**:
- No direct fund extraction possible
- Time-locked admin functions (recommended for production)
- Multi-sig ownership (recommended for production)

#### 3.4.2 Pool Contract Compromise

**Threat**: Underlying pool contract is exploited.

**Severity**: Critical

**Impact**: Funds in that pool could be lost

**Mitigations**:
- 70/30 diversification limits exposure
- Emergency exit function to recover remaining funds
- Integration with audited protocols only (for production)

### 3.5 Logic Errors

#### 3.5.1 Incorrect Rate Comparison

**Threat**: Rates compared incorrectly leading to wrong rebalancing direction.

**Severity**: High

**Mitigations**:
- Simple comparison logic (easy to verify)
- Comprehensive test coverage
- Events for monitoring and verification

```solidity
if (rateA > rateB) {
    _rebalance(address(poolB), address(poolA)); // Move to higher yield
} else {
    _rebalance(address(poolA), address(poolB));
}
```

#### 3.5.2 Share Calculation Errors

**Threat**: Incorrect share calculations lead to value extraction.

**Severity**: Critical

**Mitigations**:
- Standard ERC4626-like logic
- First deposit is 1:1
- Proportional calculations use consistent formula
- Fuzz testing for edge cases

## 4. Security Properties (Invariants)

### 4.1 Critical Invariants

1. **No Unauthorized Rebalance**: Only authorized ReactVM can trigger rebalancing
2. **User Fund Safety**: User can always withdraw their proportional share
3. **No Value Extraction**: Total assets >= total shares * share price
4. **Rebalance Rate Limiting**: Minimum time between rebalances enforced

### 4.2 Invariant Checks

```solidity
// In tests
function invariant_totalAssetsGeqShares() public view {
    assertTrue(vault.totalAssets() >= vault.totalShares());
}

function invariant_userCanAlwaysWithdraw() public {
    uint256 userShares = vault.sharesOf(user);
    assertTrue(vault.totalAssets() >= vault.convertToAssets(userShares));
}
```

## 5. Risk Matrix

| Risk | Likelihood | Impact | Severity | Status |
|------|------------|--------|----------|--------|
| Reentrancy | Low | Critical | High | Mitigated |
| Rate Manipulation | Medium | High | High | Partially Mitigated |
| ReactVM Spoofing | Very Low | Critical | Medium | Mitigated |
| Key Compromise | Low | Critical | High | Partially Mitigated |
| Contract Bug | Medium | Critical | High | Testing/Audit |
| Pool Compromise | Low | High | Medium | Diversification |

## 6. Recommendations

### 6.1 For Production Deployment

1. **Audit**: Professional security audit before mainnet deployment
2. **Multi-sig**: Use multi-sig for owner functions
3. **Timelock**: Add timelock for parameter changes
4. **Monitoring**: Set up event monitoring and alerting
5. **Bug Bounty**: Launch bug bounty program
6. **Insurance**: Consider DeFi insurance coverage

### 6.2 Parameters Tuning

| Parameter | Conservative | Balanced | Aggressive |
|-----------|-------------|----------|------------|
| Rebalance Threshold | 200 bps | 100 bps | 50 bps |
| Cooldown | 300s | 60s | 30s |
| Rebalance % | 25% | 50% | 75% |

### 6.3 Emergency Procedures

1. **Pause**: Immediately set authorizedReactVM to address(0)
2. **Exit**: Call emergencyExitPools() to withdraw from pools
3. **Recover**: Emergency withdraw tokens from vault
4. **Communicate**: Notify users through established channels

## 7. Conclusion

The Cross-Chain Lending Automation Vault implements multiple layers of security to protect user funds. The primary risks are mitigated through:

- Reentrancy guards
- Access control
- Rate limiting
- Diversification
- Emergency functions

Residual risks include economic attacks via rate manipulation and smart contract bugs. These should be addressed through professional auditing, conservative parameter settings, and ongoing monitoring before production deployment.
