# Step-by-Step Workflow with Transaction Hashes

This document provides a complete step-by-step walkthrough of deploying and testing the Cross-Chain Lending Automation Vault, including all transaction hashes.

## Prerequisites

- Ethereum Sepolia testnet ETH (get from [faucet](https://sepoliafaucet.com/))
- Reactive Network REACT tokens (send SepETH to Reactive faucet)
- Private key with funds on both networks

## Step 1: Deploy Origin Contracts to Ethereum Sepolia

### 1.1 Deploy MockToken, Pool A, Pool B, and LendingVault

```bash
forge script script/DeployOrigin.s.sol:DeployOriginContracts \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

**Transaction Hashes:**

| Contract | Deploy Tx Hash | Contract Address |
|----------|---------------|------------------|
| MockToken | `0x_TOKEN_DEPLOY_TX_HASH` | `0x_TOKEN_ADDRESS` |
| Pool A | `0x_POOL_A_DEPLOY_TX_HASH` | `0x_POOL_A_ADDRESS` |
| Pool B | `0x_POOL_B_DEPLOY_TX_HASH` | `0x_POOL_B_ADDRESS` |
| LendingVault | `0x_VAULT_DEPLOY_TX_HASH` | `0x_VAULT_ADDRESS` |
| Token Mint | `0x_TOKEN_MINT_TX_HASH` | - |

**Example Output:**
```
Deploying Origin Contracts to Sepolia
Deployer: 0xYourAddress
Balance: 0.5 ETH

MockToken deployed at: 0x...
Pool A deployed at: 0x...
Pool B deployed at: 0x...
LendingVault deployed at: 0x...
Minted 1,000,000 tokens to deployer

=== DEPLOYMENT SUMMARY ===
Network: Sepolia
```

---

## Step 2: Get REACT Tokens from Faucet

### 2.1 Send SepETH to Reactive Faucet

```bash
cast send 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --value 0.1ether
```

**Transaction Hash:**

| Operation | Tx Hash | Network |
|-----------|---------|---------|
| Send to Faucet | `0x_FAUCET_TX_HASH` | Sepolia |

**Result:** Receive 10 REACT tokens on Reactive Lasna Testnet

---

## Step 3: Deploy Reactive Contract to Reactive Network

### 3.1 Update Environment Variables

```bash
export POOL_A_ADDRESS=0x_POOL_A_ADDRESS
export POOL_B_ADDRESS=0x_POOL_B_ADDRESS  
export LENDING_VAULT_ADDRESS=0x_VAULT_ADDRESS
```

### 3.2 Deploy YieldMonitorReactive

```bash
forge script script/DeployReactive.s.sol:DeployReactive \
  --rpc-url https://lasna-rpc.rnk.dev/ \
  --broadcast
```

**Transaction Hash:**

| Operation | Tx Hash | Network | Contract Address |
|-----------|---------|---------|------------------|
| Deploy Reactive | `0x_REACTIVE_DEPLOY_TX_HASH` | Reactive Lasna | `0x_REACTIVE_ADDRESS` |

---

## Step 4: Configure LendingVault with ReactVM ID

### 4.1 Set Authorized ReactVM

The ReactVM ID is your deployer address on Reactive Network.

```bash
export REACTVM_ID=0xYourDeployerAddress

forge script script/SetupVault.s.sol:SetupVault \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

**Transaction Hash:**

| Operation | Tx Hash | Network |
|-----------|---------|---------|
| setAuthorizedReactVM | `0x_SETUP_VAULT_TX_HASH` | Sepolia |

---

## Step 5: Test the Vault - User Deposit

### 5.1 Approve and Deposit Tokens

```bash
# First, export addresses
export TOKEN_ADDRESS=0x_TOKEN_ADDRESS

# Deposit 10,000 tokens
forge script script/TestWorkflow.s.sol:TestWorkflow \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --sig "depositToVault()"
```

**Transaction Hashes:**

| Operation | Tx Hash | Network |
|-----------|---------|---------|
| Token Approve | `0x_APPROVE_TX_HASH` | Sepolia |
| Vault Deposit | `0x_DEPOSIT_TX_HASH` | Sepolia |

**Expected Result:**
- User receives 10,000 vault shares
- ~7,000 tokens allocated to Pool A (higher yield)
- ~3,000 tokens allocated to Pool B

---

## Step 6: Trigger Rebalancing - Update Pool Rates

### 6.1 Update Pool B to Have Higher Rate

This simulates Pool B offering better yields (triggers rebalance from A to B).

```bash
forge script script/TestWorkflow.s.sol:TestWorkflow \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --sig "updatePoolBRates()"
```

**Transaction Hash (Origin):**

| Operation | Tx Hash | Network |
|-----------|---------|---------|
| updateRates (Pool B) | `0x_RATE_UPDATE_TX_HASH` | Sepolia |

**Event Emitted:**
```
RateUpdated(1000, 1500, timestamp)  // 10% supply rate, 15% borrow rate
```

---

## Step 7: Reactive Contract Processes Event

### 7.1 Reactive Transaction

The Reactive Network automatically:
1. Captures the `RateUpdated` event
2. Calls `react()` on YieldMonitorReactive
3. Evaluates conditions (rate diff = 10% - 5% = 5% > 1% threshold)
4. Emits `Callback` event

**Reactive Transaction Hash:**

| Operation | Tx Hash | Network |
|-----------|---------|---------|
| react() execution | `0x_REACTIVE_TX_HASH` | Reactive Lasna |

**Events in Reactive Transaction:**
```
RateUpdateProcessed(poolB, 1000, timestamp, blockNumber)
RebalanceConditionMet(500, 1000, 500, blockNumber)
Callback(11155111, vaultAddress, 1000000, payload)
```

---

## Step 8: Callback Executes Rebalance on Sepolia

### 8.1 Destination Transaction

The Reactive Network submits the callback transaction to Sepolia.

**Destination Transaction Hash:**

| Operation | Tx Hash | Network |
|-----------|---------|---------|
| executeRebalance() | `0x_REBALANCE_TX_HASH` | Sepolia |

**Events in Rebalance Transaction:**
```
RebalanceTriggered(caller, 500, 1000, 500)
Withdraw(vault, amount, shares)        // From Pool A
Deposit(vault, amount, shares)         // To Pool B
Rebalance(poolA, poolB, amount, 500, 1000)
```

---

## Step 9: Verify Results

### 9.1 Check Vault Status

```bash
forge script script/TestWorkflow.s.sol:TestWorkflow \
  --rpc-url $SEPOLIA_RPC_URL \
  --sig "checkStatus()"
```

**Expected Output:**
```
=== Current Status ===

Pool A:
  Supply Rate: 500 bps
  Total Assets: ~3500 tokens (reduced)

Pool B:
  Supply Rate: 1000 bps
  Total Assets: ~6500 tokens (increased)

Vault:
  Total Assets: ~10000 tokens
  Total Shares: 10000
  Allocation in Pool A: ~3500 tokens
  Allocation in Pool B: ~6500 tokens
  Can Rebalance: No
  Reason: Cooldown not elapsed
```

---

## Step 10: User Withdrawal

### 10.1 Withdraw from Vault

```bash
forge script script/TestWorkflow.s.sol:TestWorkflow \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --sig "withdrawFromVault()"
```

**Transaction Hash:**

| Operation | Tx Hash | Network |
|-----------|---------|---------|
| Vault Withdraw | `0x_WITHDRAW_TX_HASH` | Sepolia |

---

## Complete Transaction Summary

### Origin Chain (Ethereum Sepolia)

| Step | Operation | Tx Hash | Block |
|------|-----------|---------|-------|
| 1.1 | Deploy MockToken | `0x...` | - |
| 1.2 | Deploy Pool A | `0x...` | - |
| 1.3 | Deploy Pool B | `0x...` | - |
| 1.4 | Deploy LendingVault | `0x...` | - |
| 1.5 | Mint Tokens | `0x...` | - |
| 2.1 | Faucet Request | `0x...` | - |
| 4.1 | setAuthorizedReactVM | `0x...` | - |
| 5.1 | Token Approve | `0x...` | - |
| 5.2 | Vault Deposit | `0x...` | - |
| 6.1 | updateRates (Pool B) | `0x...` | - |
| 8.1 | executeRebalance (callback) | `0x...` | - |
| 10.1 | Vault Withdraw | `0x...` | - |

### Reactive Network (Lasna Testnet)

| Step | Operation | Tx Hash | Block |
|------|-----------|---------|-------|
| 3.2 | Deploy YieldMonitorReactive | `0x...` | - |
| 7.1 | react() - Process RateUpdated | `0x...` | - |

---

## Contract Addresses Summary

### Ethereum Sepolia (Chain ID: 11155111)

| Contract | Address |
|----------|---------|
| MockToken (mUSDC) | `0x...` |
| MockLendingPool A | `0x...` |
| MockLendingPool B | `0x...` |
| LendingVault | `0x...` |

### Reactive Lasna Testnet (Chain ID: 5318007)

| Contract | Address |
|----------|---------|
| YieldMonitorReactive | `0x...` |

---

## Block Explorers

- **Sepolia**: https://sepolia.etherscan.io/tx/{hash}
- **Reactive Lasna**: https://lasna.reactscan.net/tx/{hash}

---

## Troubleshooting

### Callback Not Executing

1. Check that ReactVM ID is correctly set on vault
2. Verify REACT balance for callback gas
3. Check that cooldown period has not just been hit
4. Verify rate difference exceeds threshold

### Transaction Reverts

Check the revert reason:
```bash
cast call <contract> <function> --rpc-url $SEPOLIA_RPC_URL --trace
```

Common issues:
- `Unauthorized ReactVM`: Wrong ReactVM ID set
- `Cooldown not elapsed`: Wait for cooldown
- `Rate diff below threshold`: Rates too similar
