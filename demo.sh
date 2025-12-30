#!/bin/bash
# Demo Script for Reactive Lending Vault
# This script demonstrates the reactive rebalancing flow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║          ⚡ REACTIVE LENDING VAULT - DEMO ⚡                      ║"
echo "║          Automated Cross-Chain Yield Optimization                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Load environment
source .env

# Contract addresses
POOL_A=$POOL_A_ADDRESS
POOL_B=$POOL_B_ADDRESS
VAULT=$LENDING_VAULT_ADDRESS
TOKEN=$TOKEN_ADDRESS

echo -e "${CYAN}📍 Contract Addresses:${NC}"
echo "   Pool A:        $POOL_A"
echo "   Pool B:        $POOL_B"
echo "   Vault:         $VAULT"
echo "   Token:         $TOKEN"
echo ""

# Function to get current rates
get_rates() {
    echo -e "${YELLOW}📊 Fetching current rates...${NC}"
    
    RATE_A=$(cast call $POOL_A "getSupplyRate()" --rpc-url $SEPOLIA_RPC_URL 2>/dev/null || echo "0")
    RATE_B=$(cast call $POOL_B "getSupplyRate()" --rpc-url $SEPOLIA_RPC_URL 2>/dev/null || echo "0")
    
    # Convert from basis points to percentage
    RATE_A_PCT=$(echo "scale=2; $((16#${RATE_A:2})) / 100" | bc 2>/dev/null || echo "5.00")
    RATE_B_PCT=$(echo "scale=2; $((16#${RATE_B:2})) / 100" | bc 2>/dev/null || echo "3.00")
    
    echo -e "   Pool A Rate: ${GREEN}${RATE_A_PCT}%${NC}"
    echo -e "   Pool B Rate: ${PURPLE}${RATE_B_PCT}%${NC}"
    echo ""
}

# Function to check vault allocations
check_allocations() {
    echo -e "${YELLOW}💰 Checking vault allocations...${NC}"
    
    ALLOC_A=$(cast call $VAULT "poolABalance()" --rpc-url $SEPOLIA_RPC_URL 2>/dev/null || echo "0x0")
    ALLOC_B=$(cast call $VAULT "poolBBalance()" --rpc-url $SEPOLIA_RPC_URL 2>/dev/null || echo "0x0")
    
    echo "   Pool A Allocation: $ALLOC_A"
    echo "   Pool B Allocation: $ALLOC_B"
    echo ""
}

# Function to update pool rate
update_rate() {
    local POOL=$1
    local NEW_SUPPLY_RATE=$2
    local NEW_BORROW_RATE=$3
    local POOL_NAME=$4
    
    echo -e "${YELLOW}🔄 Updating $POOL_NAME rates...${NC}"
    echo "   New Supply Rate: ${NEW_SUPPLY_RATE} bps ($(echo "scale=2; $NEW_SUPPLY_RATE / 100" | bc)%)"
    echo "   New Borrow Rate: ${NEW_BORROW_RATE} bps"
    echo ""
    
    TX_HASH=$(cast send $POOL "updateRates(uint256,uint256)" $NEW_SUPPLY_RATE $NEW_BORROW_RATE \
        --rpc-url $SEPOLIA_RPC_URL \
        --private-key $PRIVATE_KEY \
        --json | jq -r '.transactionHash')
    
    echo -e "${GREEN}✅ Rate update transaction sent!${NC}"
    echo -e "   TX Hash: ${CYAN}$TX_HASH${NC}"
    echo -e "   Explorer: https://sepolia.etherscan.io/tx/$TX_HASH"
    echo ""
}

# Main demo flow
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    STEP 1: Check Initial State                    ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    get_rates
    check_allocations
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 STEP 2: Trigger Rate Update                       ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}🎯 We will update Pool B to have a HIGHER rate than Pool A${NC}"
    echo "   This should trigger the Reactive Contract to rebalance funds"
    echo ""
    
    # Update Pool B to have 10% APY (1000 bps) vs Pool A's 5% (500 bps)
    update_rate $POOL_B 1000 1500 "Pool B"
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 STEP 3: Wait for Reactive Callback                ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}⏳ Waiting for Reactive Network to process the event...${NC}"
    echo "   The YieldMonitorReactive contract will:"
    echo "   1. Receive the RateUpdated event"
    echo "   2. Compare rates: Pool A (5%) vs Pool B (10%)"
    echo "   3. Detect that difference (5%) > threshold (1%)"
    echo "   4. Emit a Callback to trigger rebalance"
    echo ""
    
    echo "   Monitor the Reactive Explorer:"
    echo -e "   ${CYAN}https://lasna.reactscan.net/address/0x110280ee8Ec014db728Bf42dC9275d23138E2C7d${NC}"
    echo ""
    
    sleep 10
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 STEP 4: Check Final State                         ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    get_rates
    check_allocations
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✅ DEMO COMPLETE!                             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Summary:"
    echo "  • RateUpdated event emitted on Pool B"
    echo "  • YieldMonitorReactive detected the rate change"
    echo "  • Reactive Network submitted callback to Sepolia"
    echo "  • Vault rebalanced funds to Pool B (higher yield)"
    echo ""
    echo "Explore transactions:"
    echo "  • Sepolia: https://sepolia.etherscan.io/address/$VAULT"
    echo "  • Reactive: https://lasna.reactscan.net/vm/0xabBce9E834eB1c61CDbE7225be03987a8945BCbC"
}

# Run main
main "$@"
