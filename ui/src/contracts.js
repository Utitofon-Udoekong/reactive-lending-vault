// Contract addresses (Sepolia)
export const CONTRACTS = {
    TOKEN: "0xf4CD5a8E1333D7b2bb01653B87bc4379BF467c9F",
    POOL_A: "0xB67d0c4bB0B04A6132a50EBbC9151093dE7B2a05",
    POOL_B: "0x2D64e2fe12090773A549c56aA20aea5bA0905a8C",
    VAULT: "0xCC38e9E04942a99526688Bde976b5cc26D34db17",
    REACTIVE: "0x3B7B648e90c8b9c8173315b96C1FEE4CB604924a",
    REACTVM_ID: "0x3B7B648e90c8b9c8173315b96C1FEE4CB604924a"
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
