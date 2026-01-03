// Contract addresses (Sepolia)
export const CONTRACTS = {
    TOKEN: import.meta.env.VITE_TOKEN_ADDRESS,
    POOL_A: import.meta.env.VITE_POOL_A_ADDRESS,
    POOL_B: import.meta.env.VITE_POOL_B_ADDRESS,
    VAULT: import.meta.env.VITE_LENDING_VAULT_ADDRESS,
    REACTIVE: import.meta.env.VITE_REACTIVE_ADDRESS,
    REACTVM_ID: import.meta.env.VITE_REACTVM_ID
};

// Chain IDs
export const CHAINS = {
    SEPOLIA: 11155111,
    REACTIVE: 5318007
};

// Sepolia RPC (uses VITE_SEPOLIA_RPC_URL from ui/.env if available)
export const RPC_URL = import.meta.env.VITE_SEPOLIA_RPC_URL || "https://eth-sepolia.g.alchemy.com/v2/demo";

// ABIs
export const TOKEN_ABI = [
    "function balanceOf(address) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)",
    "function faucet(uint256 amount)"
];

export const POOL_ABI = [
    "function getSupplyRate() view returns (uint256)",
    "function getBorrowRate() view returns (uint256)",
    "function totalAssets() view returns (uint256)",
    "function withdraw(uint256 shares) returns (uint256 amount)",
    "function updateRates(uint256 _supplyRate, uint256 _borrowRate, uint256 _utilization)",
    "function convertToShares(uint256 assets) view returns (uint256)",
    "event RateUpdated(uint256 supplyRate, uint256 borrowRate, uint256 timestamp)",
    "event LiquidityUpdated(uint256 totalAssets)"
];

export const VAULT_ABI = [
    "function deposit(uint256 amount) returns (uint256 shares)",
    "function withdraw(uint256 shares) returns (uint256 amount)",
    "function sharesOf(address account) view returns (uint256)",
    "function totalAssets() view returns (uint256)",
    "function totalShares() view returns (uint256)",
    "function getAllocation() view returns (uint256 poolAAlloc, uint256 poolBAlloc)",
    "function canRebalance() view returns (bool canRebal, string memory reason)",
    "function executeRebalance(address rvmId)",
    "function executeEmergencyExit(address rvmId)",
    "function lastRebalanceTime() view returns (uint256)",
    "function rebalanceThreshold() view returns (uint256)",
    "function rebalancePercentage() view returns (uint256)",
    "function rebalanceCooldown() view returns (uint256)",
    "function authorizedReactVM() view returns (address)",
    "function setRebalancePercentage(uint256 _percentage)",
    "function setRebalanceThreshold(uint256 _threshold)",
    "event VaultDeposit(address indexed user, uint256 amount, uint256 shares)",
    "event VaultWithdraw(address indexed user, uint256 amount, uint256 shares)",
    "event RebalanceTriggered(address indexed caller, uint256 rateA, uint256 rateB, uint256 rateDiff)",
    "event Rebalance(address indexed fromPool, address indexed toPool, uint256 amount, uint256 rateA, uint256 rateB)",
    "event EmergencyExitTriggered(address indexed caller)"
];
