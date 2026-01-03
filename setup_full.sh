#!/bin/bash
set -e
source .env

echo "=== 1. Authorizing ReactVM on Vault (Sepolia) ==="
forge script script/SetupVault.s.sol:SetupVault --rpc-url $SEPOLIA_RPC_URL --broadcast

echo "=== 2. Funding Vault with ETH (Sepolia - 0.05 ETH) ==="
cast send --rpc-url $SEPOLIA_RPC_URL $LENDING_VAULT_ADDRESS --value 0.05ether --private-key $PRIVATE_KEY

echo "=== 3. Funding Reactive Contract (Lasna - 0.1 ETH) ==="
cast send --rpc-url https://lasna-rpc.rnk.dev/ $REACTIVE_ADDRESS --value 0.1ether --private-key $PRIVATE_KEY --legacy

echo "=== 4. Activating Subscriptions (Lasna) ==="
cast send --rpc-url https://lasna-rpc.rnk.dev/ $REACTIVE_ADDRESS "setupSubscriptions()" --private-key $PRIVATE_KEY --legacy

echo "=== SETUP COMPLETE ==="
