#!/bin/bash
set -e

# Load environment variables
source .env

echo "=========================================="
echo " Reactive Lending Vault Deployment Script"
echo "=========================================="

# Check if required env vars are set
if [ -z "$PRIVATE_KEY" ] || [ -z "$SEPOLIA_RPC_URL" ]; then
    echo "ERROR: Please set PRIVATE_KEY and SEPOLIA_RPC_URL in .env"
    exit 1
fi

# Step 1: Deploy to Sepolia
echo ""
echo "[1/3] Deploying Origin Contracts to Sepolia..."
forge script script/DeployOrigin.s.sol:DeployOriginContracts \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    -vvv

echo ""
echo "Please update your .env with the deployed addresses:"
echo "TOKEN_ADDRESS=<from output above>"
echo "POOL_A_ADDRESS=<from output above>"
echo "POOL_B_ADDRESS=<from output above>"
echo "LENDING_VAULT_ADDRESS=<from output above>"
echo ""
read -p "Press Enter after updating .env to continue..."

# Reload env after update
source .env

# Step 2: Deploy to Reactive Network
echo ""
echo "[2/3] Deploying Reactive Contract to Reactive Network..."
echo "Note: Sending 0.1 ETH with the contract for callbacks"
forge script script/DeployReactive.s.sol:DeployReactive \
    --rpc-url "https://lasna-rpc.rnk.dev/" \
    --broadcast \
    -vvv

echo ""
echo "Please note the ReactVM ID (your deployer address):"
echo "REACTVM_ID=<your deployer address>"
read -p "Press Enter after updating .env to continue..."

# Step 3: Setup vault authorization
source .env
echo ""
echo "[3/3] Setting up Vault Authorization..."
forge script script/SetupVault.s.sol:SetupVault \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    -vvv

echo ""
echo "=========================================="
echo " Deployment Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Update docs/WORKFLOW.md with transaction hashes"
echo "2. Test the workflow by calling updateRates() on pools"
echo "3. Record a demo video"
