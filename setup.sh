#!/bin/bash

# Cross-Chain Lending Automation Vault - Setup Script

set -e

echo "========================================"
echo "Cross-Chain Lending Automation Vault"
echo "Setup Script"
echo "========================================"

# Check for Foundry
if ! command -v forge &> /dev/null; then
    echo "Foundry not found. Installing..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
fi

echo "Foundry version: $(forge --version)"

# Install dependencies
echo ""
echo "Installing dependencies..."
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit

# Build
echo ""
echo "Building contracts..."
forge build

# Run tests
echo ""
echo "Running tests..."
forge test

echo ""
echo "========================================"
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy .env.example to .env and fill in your values"
echo "2. Run deployment scripts (see README.md)"
echo "========================================"
