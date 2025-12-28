# Cross-Chain Lending Automation Vault

A decentralized lending vault that automatically rebalances funds between multiple lending pools based on yield optimization, powered by **Reactive Smart Contracts**.

## 🎯 Overview

This project implements a cross-chain lending automation vault that:
- Integrates with **two lending pools** (Pool A and Pool B) on Ethereum Sepolia
- Uses **Reactive Smart Contracts** to monitor on-chain yield rates
- **Automatically rebalances** funds when yield conditions warrant it
- Provides a **single vault interface** for users - deposit once, earn optimized yields automatically

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           ETHEREUM SEPOLIA                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │   Pool A     │    │   Pool B     │    │     LendingVault         │  │
│  │ (5% APY)     │    │ (3% APY)     │    │   (Destination)          │  │
│  │              │    │              │    │                          │  │
│  │ RateUpdated  │    │ RateUpdated  │    │  deposit()               │  │
│  │ Event ──────►│    │ Event ──────►│    │  withdraw()              │  │
│  └──────────────┘    └──────────────┘    │  executeRebalance() ◄────│──┤
│         │                   │            └──────────────────────────┘  │
│         │                   │                                          │
└─────────┼───────────────────┼──────────────────────────────────────────┘
          │                   │
          ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      REACTIVE NETWORK (LASNA)                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                  YieldMonitorReactive                             │  │
│  │                                                                   │  │
│  │  subscribe(Pool A, RateUpdated)                                   │  │
│  │  subscribe(Pool B, RateUpdated)                                   │  │
│  │                                                                   │  │
│  │  react(log) {                                                     │  │
│  │    - Update stored rates                                          │  │
│  │    - Check if rate difference > threshold                         │  │
│  │    - If yes: emit Callback(executeRebalance)                      │  │
│  │  }                                                                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                              │                                          │
│                              ▼                                          │
│                   Callback Transaction                                  │
│                   to Sepolia Vault                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

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
├── test/
│   ├── LendingVault.t.sol         # Vault tests
│   ├── MockLendingPool.t.sol      # Pool tests
│   └── YieldMonitorReactive.t.sol # Reactive contract tests
└── docs/
    ├── DESIGN.md                  # Detailed design documentation
    ├── THREAT_MODEL.md            # Security analysis
    └── WORKFLOW.md                # Step-by-step workflow with tx hashes
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

See [THREAT_MODEL.md](docs/THREAT_MODEL.md) for detailed security analysis.

Key security features:
- **ReactVM Authorization**: Only the authorized ReactVM can trigger rebalances
- **Cooldown Period**: Prevents rapid-fire rebalancing attacks
- **Threshold Requirement**: Prevents unnecessary rebalances for small rate changes
- **Reentrancy Protection**: All external functions protected with `nonReentrant`
- **Owner Controls**: Emergency functions for pausing and recovery

## 🎥 Demo Video

[Watch the 5-minute demo video explaining the design, threat model, and trade-offs]

## 📜 Contract Addresses

### Ethereum Sepolia

| Contract | Address |
|----------|---------|
| MockToken | `0x...` |
| Pool A | `0x...` |
| Pool B | `0x...` |
| LendingVault | `0x...` |

### Reactive Lasna Testnet

| Contract | Address |
|----------|---------|
| YieldMonitorReactive | `0x...` |

## 📝 Transaction Hashes

See [WORKFLOW.md](docs/WORKFLOW.md) for complete transaction history.

## 🤔 Why Reactive Contracts?

### The Problem Without Reactive Contracts

Without Reactive Contracts, achieving automated yield optimization requires:

1. **Off-chain Infrastructure**: A centralized server monitoring on-chain rates
2. **Keeper Network**: Expensive keeper bots (Gelato, Chainlink Automation)
3. **Manual Intervention**: Users monitoring and triggering rebalances themselves
4. **Trust Assumptions**: Users must trust centralized automation providers

### Why Reactive Contracts Are Better

1. **Fully On-Chain Automation**: No off-chain components required
2. **Trustless Execution**: Smart contracts handle everything autonomously
3. **Event-Driven**: Immediate response to rate changes
4. **Cost-Effective**: No ongoing keeper fees or infrastructure costs
5. **Censorship Resistant**: No central point of failure

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [Reactive Network](https://reactive.network/) for the Reactive Smart Contract infrastructure
- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Foundry](https://github.com/foundry-rs/foundry) for the development framework
