# Cross-Chain Lending Automation Vault

A decentralized lending vault that automatically rebalances funds between multiple lending pools based on yield optimization, powered by **Reactive Smart Contracts**.

## 🎯 Overview

This project implements a cross-chain lending automation vault that:
- Integrates with **two lending pools** (Pool A and Pool B) on Ethereum Sepolia
- Uses **Reactive Smart Contracts** to monitor on-chain yield rates
- **Automatically rebalances** funds when yield conditions warrant it
- Provides a **single vault interface** for users - deposit once, earn optimized yields automatically

## 🏗️ Architecture

**Ethereum Sepolia (Origin Chain)**
| Contract | Purpose |
|----------|---------|
| Pool A | Lending pool with variable APY, emits `RateUpdated` events |
| Pool B | Lending pool with variable APY, emits `RateUpdated` events |
| LendingVault | User-facing vault - `deposit()`, `withdraw()`, `executeRebalance()` |

⬇️ Events flow to Reactive Network ⬇️

**Reactive Network (Lasna)**
| Contract | Purpose |
|----------|---------|
| YieldMonitorReactive | Subscribes to pool events, monitors rates, emits `Callback` when rebalance needed |

⬆️ Callback triggers `executeRebalance()` on Vault ⬆️

## 📋 Project Structure

```
reactive-lending-vault/
├── src/
│   ├── interfaces/
│   │   ├── IReactive.sol          # Reactive Network interface
│   │   ├── ISystemContract.sol    # System contract interface
│   │   ├── ILendingPool.sol       # Lending pool interface
│   │   └── ILendingVault.sol      # Vault interface
│   ├── origin/
│   │   ├── MockLendingPool.sol    # Mock lending pool (Pool A & B)
│   │   └── MockToken.sol          # Mock ERC20 token
│   ├── destination/
│   │   └── LendingVault.sol       # Main vault contract
│   └── reactive/
│       ├── AbstractReactive.sol   # Base reactive contract
│       └── YieldMonitorReactive.sol # Yield monitoring reactive contract
├── script/
│   ├── DeployOrigin.s.sol         # Deploy origin contracts to Sepolia
│   ├── DeployReactive.s.sol       # Deploy reactive contract to Reactive Network
│   ├── SetupVault.s.sol           # Setup vault authorization
│   └── TestWorkflow.s.sol         # Interactive test workflow
└── test/
    ├── LendingVault.t.sol         # Vault tests
    ├── MockLendingPool.t.sol      # Pool tests
    └── YieldMonitorReactive.t.sol # Reactive contract tests
```

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 18+
- Ethereum Sepolia testnet ETH ([faucet](https://sepoliafaucet.com/))
- Reactive Network REACT tokens

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/reactive-lending-vault.git
cd reactive-lending-vault

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts

# Copy environment file
cp .env.example .env
# Edit .env with your private key and RPC URLs
```

### Environment Variables

```bash
# .env file
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
ETHERSCAN_API_KEY=your_etherscan_api_key

# After deployment, add these:
TOKEN_ADDRESS=0x...
POOL_A_ADDRESS=0x...
POOL_B_ADDRESS=0x...
LENDING_VAULT_ADDRESS=0x...
REACTVM_ID=0x...  # Your deployer address
```

## 📦 Deployment

### Step 1: Deploy Origin Contracts to Sepolia

```bash
# Load environment
source .env

# Deploy token, pools, and vault to Sepolia
forge script script/DeployOrigin.s.sol:DeployOriginContracts \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Note the deployed addresses and add them to .env
```

### Step 2: Get REACT Tokens

Send SepETH to the Reactive faucet on Sepolia to receive REACT:
```bash
cast send 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --value 0.1ether
```

### Step 3: Deploy Reactive Contract

```bash
# Deploy to Reactive Lasna Testnet
forge script script/DeployReactive.s.sol:DeployReactive \
  --rpc-url https://lasna-rpc.rnk.dev/ \
  --broadcast
```

### Step 4: Setup Vault Authorization

```bash
# Set REACTVM_ID to your deployer address
export REACTVM_ID=<your_deployer_address>

# Authorize the ReactVM on the vault
forge script script/SetupVault.s.sol:SetupVault \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

## 🧪 Testing

### Run Unit Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-contract LendingVaultTest -vvv

# Run with coverage
forge coverage
```

### Interactive Testing

```bash
# Deposit tokens to vault
forge script script/TestWorkflow.s.sol:TestWorkflow \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --sig "depositToVault()"

# Update Pool A rates (triggers reactive monitoring)
forge script script/TestWorkflow.s.sol:TestWorkflow \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --sig "updatePoolARates()"

# Check current status
forge script script/TestWorkflow.s.sol:TestWorkflow \
  --rpc-url $SEPOLIA_RPC_URL \
  --sig "checkStatus()"
```

## 🔧 Configuration

### Vault Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rebalanceThreshold` | 100 (1%) | Minimum rate difference to trigger rebalance |
| `rebalanceCooldown` | 60 seconds | Minimum time between rebalances |
| `rebalancePercentage` | 5000 (50%) | Percentage of funds to move on rebalance |

### Reactive Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `minBlocksBetweenRebalance` | 5 blocks | Minimum blocks between callbacks |
| `CALLBACK_GAS_LIMIT` | 1,000,000 | Gas limit for callback transactions |

## 📊 How Rebalancing Works

1. **Rate Change Detection**: When Pool A or Pool B updates their rates, they emit a `RateUpdated` event
2. **Event Subscription**: The Reactive Contract subscribes to these events from both pools
3. **Rate Comparison**: The `react()` function stores the latest rates and compares them
4. **Threshold Check**: If the rate difference exceeds the threshold (default 1%), rebalancing is triggered
5. **Callback Emission**: A `Callback` event is emitted with the `executeRebalance()` payload
6. **Cross-Chain Execution**: Reactive Network submits the transaction to the LendingVault on Sepolia
7. **Fund Movement**: The vault moves funds from the lower-yielding pool to the higher-yielding pool

## 🔐 Security Considerations

### Threat Model

| Threat | Mitigation |
|--------|------------|
| Unauthorized rebalance | Only authorized ReactVM can call `executeRebalance()` |
| Flash loan attacks | Cooldown period prevents rapid rebalancing |
| Rate manipulation | Threshold prevents micro-arbitrage exploitation |
| Reentrancy | All external functions use `nonReentrant` modifier |
| Fund extraction | Only depositors can withdraw their shares |

### Key Security Features
- **ReactVM Authorization**: Only the authorized ReactVM can trigger rebalances
- **Cooldown Period**: Prevents rapid-fire rebalancing attacks  
- **Threshold Requirement**: Prevents unnecessary rebalances for small rate changes
- **Reentrancy Protection**: All external functions protected with `nonReentrant`
- **Owner Controls**: Emergency functions for pausing and recovery

## 📜 Deployed Contracts

### Ethereum Sepolia - Origin & Destination (Chain ID: 11155111)

| Contract | Address | Role |
|----------|---------|------|
| MockToken (mUSDC) | [`0xd9414ec336f0a7cc5932e48c023fa063aa783e79`](https://sepolia.etherscan.io/address/0xd9414ec336f0a7cc5932e48c023fa063aa783e79) | ERC20 Token |
| Pool A | [`0x75b43879d502244290e2a3e3f548d419deafbc10`](https://sepolia.etherscan.io/address/0x75b43879d502244290e2a3e3f548d419deafbc10) | Origin (emits RateUpdated events) |
| Pool B | [`0x3e7a5146e71977c9cbeee16e2ad8e2a41b92c58d`](https://sepolia.etherscan.io/address/0x3e7a5146e71977c9cbeee16e2ad8e2a41b92c58d) | Origin (emits RateUpdated events) |
| LendingVault | [`0x7e3201c3f38214d5a23b1e62de4196c3efc1bad2`](https://sepolia.etherscan.io/address/0x7e3201c3f38214d5a23b1e62de4196c3efc1bad2) | Destination (receives callbacks) |

### Reactive Network Lasna Testnet (Chain ID: 5318007)

| Contract | Address | Role |
|----------|---------|------|
| YieldMonitorReactive | [`0x0Ef6513895243C624b97033232A0444D612c886D`](https://lasna.reactscan.net/address/0x0Ef6513895243C624b97033232A0444D612c886D) | Reactive Contract |

**ReactVM ID (Deployer Address):** `0xabBce9E834eB1c61CDbE7225be03987a8945BCbC`

> **Note:** The ReactVM ID is the deployer's wallet address. All contracts deployed by the same address share a single ReactVM instance on the Reactive Network. The Callback Proxy injects this address into callback payloads for authorization.

## 📝 Step-by-Step Workflow & Transaction Hashes

This section documents the complete workflow execution with transaction hashes for verification.

### Step 1: Deploy Origin Contracts (Sepolia)

Deployed MockToken, Pool A, Pool B, and LendingVault to Ethereum Sepolia.

| Contract | Explorer Link |
|----------|---------------|
| MockToken | [View on Etherscan](https://sepolia.etherscan.io/address/0xd9414ec336f0a7cc5932e48c023fa063aa783e79) |
| Pool A | [View on Etherscan](https://sepolia.etherscan.io/address/0x75b43879d502244290e2a3e3f548d419deafbc10) |
| Pool B | [View on Etherscan](https://sepolia.etherscan.io/address/0x3e7a5146e71977c9cbeee16e2ad8e2a41b92c58d) |
| LendingVault | [View on Etherscan](https://sepolia.etherscan.io/address/0x7e3201c3f38214d5a23b1e62de4196c3efc1bad2) |

### Step 2: Deploy Reactive Contract (Lasna)

Deployed YieldMonitorReactive to Reactive Network Lasna Testnet with 0.1 ETH for callbacks.

| Action | Explorer |
|--------|----------|
| Deploy YieldMonitorReactive | [View on ReactScan](https://lasna.reactscan.net/address/0x878d0819a92B887a2851d817CA30ABc7857d6603) |

### Step 3: Authorize ReactVM on Vault (Sepolia)

Updated the LendingVault to authorize the ReactVM ID (deployer address) for callbacks.

| Action | Tx Hash | Network |
|--------|---------|---------|
| Set Authorized ReactVM | [`0xe5c6319594ddf999433ee8056058b4a965cf25edb0c031cde38e0ca0ff10b127`](https://sepolia.etherscan.io/tx/0xe5c6319594ddf999433ee8056058b4a965cf25edb0c031cde38e0ca0ff10b127) | Sepolia |

### Step 4: Fund Vault with ETH (Sepolia)

Sent ETH to the LendingVault to pay for callback gas costs on the destination chain.

| Action | Tx Hash | Network |
|--------|---------|---------|
| Fund Vault (0.01 ETH) | [`0x6fe53b037cca015138e181f9863144dff0861b100d36c57635566a04be5f0d9d`](https://sepolia.etherscan.io/tx/0x6fe53b037cca015138e181f9863144dff0861b100d36c57635566a04be5f0d9d) | Sepolia |

### Step 5: User Deposits to Vault (Origin Transaction)

User deposits tokens into the vault, which allocates to pools based on current rates.

| Action | Tx Hash | Network |
|--------|---------|---------|
| Deposit tokens | *Pending user action* | Sepolia |

### Step 6: Trigger Rate Change (Origin Transaction)

Pool rate is updated, emitting the `RateUpdated` event that the Reactive Contract monitors.

| Action | Tx Hash | Network |
|--------|---------|---------|
| Update Pool Rate | *Pending user action* | Sepolia |

### Step 7: Reactive Contract Processes Event (Reactive Transaction)

The Reactive Network captures the event, executes the `react()` function, and emits a `Callback` event.

| Action | Explorer |
|--------|----------|
| React to Event | [View on ReactScan](https://lasna.reactscan.net/address/0xabbce9e834eb1c61cdbe7225be03987a8945bcbc) |

### Step 8: Callback Execution (Destination Transaction)

The Reactive Network delivers the callback to execute `executeRebalance()` on the vault.

| Action | Tx Hash | Network |
|--------|---------|---------|
| Execute Rebalance | *Triggered by callback* | Sepolia |

**Block Explorers:**
- **Sepolia:** https://sepolia.etherscan.io
- **Reactive Lasna:** https://lasna.reactscan.net

## 🤔 Why Reactive Contracts?

### The Problem: Automated Yield Optimization is Hard

**Without Reactive Contracts**, achieving automated yield optimization requires one of these approaches:

| Approach | Problems |
|----------|----------|
| **Centralized Bots** | Single point of failure, requires 24/7 infrastructure, trust assumptions |
| **Keeper Networks (Gelato/Chainlink)** | Ongoing fees ($100s-$1000s/month), complex setup, external dependencies |
| **Manual Monitoring** | Human latency (hours/days), missed opportunities, not scalable |
| **Polling-Based Solutions** | Wasteful (constant RPC calls), slow reaction (polling intervals), expensive |

**The core challenge:** Traditional smart contracts are *passive* - they can only execute when explicitly called by an EOA. There's no native way for a contract to "watch" for events and automatically respond.

### Why Reactive Contracts Are the Solution

Reactive Contracts solve this through **Inversion of Control (IoC)**:

| Feature | Benefit |
|---------|---------|
| **Event-Driven Execution** | Contract automatically executes when subscribed events occur |
| **Fully On-Chain** | No off-chain infrastructure, servers, or bots needed |
| **Trustless** | No intermediaries, keepers, or centralized operators |
| **Cost-Effective** | Pay per callback, no ongoing subscription fees |
| **Immediate Response** | Reacts as soon as the event is emitted, no polling delays |
| **Censorship Resistant** | Decentralized infrastructure, no single point of failure |

### Without Reactive Contracts, This Would Be Impossible

To achieve the same functionality without Reactive Contracts, you would need:

1. **A dedicated server** running 24/7, monitoring both pools for rate changes
2. **A hot wallet** with private keys on the server, funding for gas
3. **Monitoring infrastructure** for alerting on server downtime
4. **Security measures** to protect the hot wallet from compromise
5. **Keeper fallbacks** in case the primary server fails

**Cost estimate:** $500-2000/month for infrastructure + security risks

With Reactive Contracts: **Deploy once, runs forever, fully trustless.**

### Reactivity in This Application

This project demonstrates meaningful use of Reactive Contracts:

1. **Event Subscription**: Subscribes to `RateUpdated` events from two lending pools
2. **State Accumulation**: Stores rate history in ReactVM state for comparison
3. **Conditional Logic**: Only triggers rebalance when rate difference > threshold
4. **Cross-Chain Callback**: Emits `Callback` to execute `executeRebalance()` on destination

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [Reactive Network](https://reactive.network/) for the Reactive Smart Contract infrastructure
- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Foundry](https://github.com/foundry-rs/foundry) for the development framework
