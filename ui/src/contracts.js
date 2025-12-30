// Contract addresses (Sepolia)
export const CONTRACTS = {
    TOKEN: "0x7069d29c5fD16280ed972Cf1931b852425D11207",
    POOL_A: "0x9297c4A7c171566149763463288BdE43670663A6",
    POOL_B: "0x2916d116C9042A7EF88f462111c011403Db77D7C",
    VAULT: "0xDe77B417f9102079f3BA3AE16c69226140E8dc9b",
    REACTIVE: "0x110280ee8Ec014db728Bf42dC9275d23138E2C7d",
    REACTVM_ID: "0xabBce9E834eB1c61CDbE7225be03987a8945BCbC"
};

// Chain IDs
export const CHAINS = {
    SEPOLIA: 11155111,
    REACTIVE: 5318007
};

// Sepolia RPC
export const RPC_URL = "https://eth-sepolia.g.alchemy.com/v2/demo";

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
    "function totalDeposits() view returns (uint256)",
    "function updateRates(uint256 _supplyRate, uint256 _borrowRate, uint256 _utilization)",
    "event RateUpdated(uint256 supplyRate, uint256 borrowRate, uint256 timestamp)"
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
    "function lastRebalanceTime() view returns (uint256)",
    "function rebalanceThreshold() view returns (uint256)",
    "function rebalancePercentage() view returns (uint256)",
    "function rebalanceCooldown() view returns (uint256)",
    "function authorizedReactVM() view returns (address)",
    "function setRebalancePercentage(uint256 _percentage)",
    "function setRebalanceThreshold(uint256 _threshold)",
    "event Deposit(address indexed user, uint256 amount, uint256 shares)",
    "event Withdraw(address indexed user, uint256 amount, uint256 shares)",
    "event Rebalance(address indexed fromPool, address indexed toPool, uint256 amount, uint256 rateA, uint256 rateB)"
];
