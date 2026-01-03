// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/ILendingVault.sol";

/**
 * @title LendingVault
 * @notice Cross-chain lending automation vault - Destination Contract
 * @dev This is the destination contract that receives callbacks from the Reactive Contract.
 *      Users deposit funds here, and the vault automatically allocates them between
 *      Pool A and Pool B. The Reactive Contract triggers rebalancing when yield
 *      conditions change.
 *
 * Architecture:
 * - Users deposit/withdraw through this vault
 * - Vault holds shares in Pool A and Pool B
 * - Reactive Contract monitors rate changes and calls executeRebalance()
 * - Rebalancing moves funds from lower-yielding to higher-yielding pool
 */
contract LendingVault is ILendingVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ===== State Variables =====

    /// @notice The underlying asset token
    IERC20 public immutable asset;

    /// @notice Lending Pool A
    ILendingPool public immutable poolA;

    /// @notice Lending Pool B
    ILendingPool public immutable poolB;

    /// @notice Authorized ReactVM ID that can call executeRebalance
    address public authorizedReactVM;

    /// @notice Total vault shares minted
    uint256 public override totalShares;

    /// @notice Mapping of user shares
    mapping(address => uint256) private _shares;

    /// @notice Minimum rate difference to trigger rebalance (in basis points)
    uint256 public rebalanceThreshold;

    /// @notice Minimum time between rebalances (seconds)
    uint256 public rebalanceCooldown;

    /// @notice Last rebalance timestamp
    uint256 public lastRebalanceTime;

    /// @notice Percentage to rebalance (in basis points, e.g., 5000 = 50%)
    uint256 public rebalancePercentage;

    /// @notice Minimum deposit amount
    uint256 public constant MIN_DEPOSIT = 1e6;

    /// @notice Basis points denominator
    uint256 public constant BPS = 10000;

    // ===== Events =====

    event AuthorizedReactVMUpdated(
        address indexed oldRVM,
        address indexed newRVM
    );
    event ThresholdUpdated(
        uint256 indexed oldThreshold,
        uint256 indexed newThreshold
    );
    event CooldownUpdated(
        uint256 indexed oldCooldown,
        uint256 indexed newCooldown
    );
    event RebalancePercentageUpdated(
        uint256 indexed oldPct,
        uint256 indexed newPct
    );
    event EmergencyExitTriggered(address indexed caller);

    // ===== Constructor =====

    /**
     * @notice Initialize the lending vault
     * @param _asset The underlying asset token
     * @param _poolA Address of Lending Pool A
     * @param _poolB Address of Lending Pool B
     * @param _rebalanceThreshold Minimum rate difference to trigger rebalance (bps)
     * @param _rebalanceCooldown Minimum time between rebalances (seconds)
     * @param _rebalancePercentage Percentage of funds to move on rebalance (bps)
     */
    constructor(
        address _asset,
        address _poolA,
        address _poolB,
        uint256 _rebalanceThreshold,
        uint256 _rebalanceCooldown,
        uint256 _rebalancePercentage
    ) Ownable(msg.sender) {
        require(_asset != address(0), "Invalid asset");
        require(_poolA != address(0), "Invalid pool A");
        require(_poolB != address(0), "Invalid pool B");
        require(_rebalanceThreshold > 0, "Invalid threshold");
        require(_rebalancePercentage <= BPS, "Invalid percentage");

        asset = IERC20(_asset);
        poolA = ILendingPool(_poolA);
        poolB = ILendingPool(_poolB);
        rebalanceThreshold = _rebalanceThreshold;
        rebalanceCooldown = _rebalanceCooldown;
        rebalancePercentage = _rebalancePercentage;

        // Approve pools to spend vault's assets (max approval for efficiency)
        asset.approve(_poolA, type(uint256).max);
        asset.approve(_poolB, type(uint256).max);
    }

    // ===== User Functions =====

    /**
     * @notice Deposit assets into the vault
     * @param amount The amount of assets to deposit
     * @return shares The vault shares minted
     */
    function deposit(
        uint256 amount
    ) external override nonReentrant returns (uint256 shares) {
        require(amount >= MIN_DEPOSIT, "Deposit too small");

        // Calculate shares before state changes
        uint256 totalAssetsBefore = totalAssets();
        if (totalShares == 0 || totalAssetsBefore == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalAssetsBefore;
        }
        require(shares > 0, "Zero shares");

        // Transfer assets from user
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Update state
        totalShares += shares;
        _shares[msg.sender] += shares;

        // Allocate to pools based on current rates
        _allocateDeposit(amount);

        emit VaultDeposit(msg.sender, amount, shares);
    }

    /**
     * @notice Withdraw assets from the vault
     * @param shares The shares to redeem
     * @return amount The amount of assets withdrawn
     */
    function withdraw(
        uint256 shares
    ) external override nonReentrant returns (uint256 amount) {
        require(shares > 0, "Zero shares");
        require(_shares[msg.sender] >= shares, "Insufficient shares");

        // Calculate proportional amount
        amount = (shares * totalAssets()) / totalShares;
        require(amount > 0, "Zero amount");

        // Update state first
        _shares[msg.sender] -= shares;
        totalShares -= shares;

        // Withdraw proportionally from pools
        _withdrawFromPools(amount);

        // Transfer to user
        asset.safeTransfer(msg.sender, amount);

        emit VaultWithdraw(msg.sender, amount, shares);
    }

    // ===== Reactive Callback =====

    /**
     * @notice Execute rebalance - called by Reactive Contract callback
     * @dev The first parameter is automatically replaced by the ReactVM ID
     * @param rvmId The ReactVM ID (injected by Reactive Network)
     */
    function executeRebalance(address rvmId) external override nonReentrant {
        require(rvmId == authorizedReactVM, "Unauthorized ReactVM");
        require(
            block.timestamp >= lastRebalanceTime + rebalanceCooldown,
            "Cooldown not elapsed"
        );

        uint256 rateA = poolA.getSupplyRate();
        uint256 rateB = poolB.getSupplyRate();

        uint256 rateDiff = rateA > rateB ? rateA - rateB : rateB - rateA;
        require(rateDiff >= rebalanceThreshold, "Rate diff below threshold");

        emit RebalanceTriggered(msg.sender, rateA, rateB, rateDiff);

        // Determine direction and execute rebalance
        if (rateA > rateB) {
            // Pool A has higher yield, move from B to A
            _rebalance(address(poolB), address(poolA));
        } else {
            // Pool B has higher yield, move from A to B
            _rebalance(address(poolA), address(poolB));
        }

        lastRebalanceTime = block.timestamp;
    }

    /**
     * @notice Emergency exit - called by Reactive Contract when bank run is detected
     * @param rvmId The ReactVM ID (injected by Reactive Network)
     */
    function executeEmergencyExit(address rvmId) external nonReentrant {
        require(rvmId == authorizedReactVM, "Unauthorized ReactVM");

        emit EmergencyExitTriggered(msg.sender);

        // Full exit from all pools
        uint256 poolAShares = poolA.sharesOf(address(this));
        uint256 poolBShares = poolB.sharesOf(address(this));

        if (poolAShares > 0) poolA.withdraw(poolAShares);
        if (poolBShares > 0) poolB.withdraw(poolBShares);
    }

    // ===== View Functions =====

    /**
     * @notice Get total assets managed by vault (sum of both pools)
     */
    function totalAssets() public view override returns (uint256) {
        uint256 poolAShares = poolA.sharesOf(address(this));
        uint256 poolBShares = poolB.sharesOf(address(this));

        uint256 poolAValue = poolA.convertToAssets(poolAShares);
        uint256 poolBValue = poolB.convertToAssets(poolBShares);

        return poolAValue + poolBValue + asset.balanceOf(address(this));
    }

    /**
     * @notice Get shares of an account
     */
    function sharesOf(
        address account
    ) external view override returns (uint256) {
        return _shares[account];
    }

    /**
     * @notice Get current allocation in both pools
     * @return poolAAlloc Value in Pool A
     * @return poolBAlloc Value in Pool B
     */
    function getAllocation()
        external
        view
        override
        returns (uint256 poolAAlloc, uint256 poolBAlloc)
    {
        uint256 poolAShares = poolA.sharesOf(address(this));
        uint256 poolBShares = poolB.sharesOf(address(this));

        poolAAlloc = poolA.convertToAssets(poolAShares);
        poolBAlloc = poolB.convertToAssets(poolBShares);
    }

    /**
     * @notice Get pool addresses
     */
    function getPoolAddresses()
        external
        view
        override
        returns (address, address)
    {
        return (address(poolA), address(poolB));
    }

    /**
     * @notice Get current rates from both pools
     */
    function getCurrentRates()
        external
        view
        returns (uint256 rateA, uint256 rateB)
    {
        rateA = poolA.getSupplyRate();
        rateB = poolB.getSupplyRate();
    }

    /**
     * @notice Check if rebalance conditions are met
     */
    function canRebalance() external view returns (bool, string memory) {
        if (block.timestamp < lastRebalanceTime + rebalanceCooldown) {
            return (false, "Cooldown not elapsed");
        }

        uint256 rateA = poolA.getSupplyRate();
        uint256 rateB = poolB.getSupplyRate();
        uint256 rateDiff = rateA > rateB ? rateA - rateB : rateB - rateA;

        if (rateDiff < rebalanceThreshold) {
            return (false, "Rate difference below threshold");
        }

        return (true, "Ready to rebalance");
    }

    // ===== Internal Functions =====

    /**
     * @notice Allocate deposited funds to pools based on current rates
     * @param amount The amount to allocate
     */
    function _allocateDeposit(uint256 amount) internal {
        uint256 rateA = poolA.getSupplyRate();
        uint256 rateB = poolB.getSupplyRate();

        // Allocate more to the higher-yielding pool
        if (rateA >= rateB) {
            // 70% to A, 30% to B (favoring higher yield)
            uint256 amountToA = (amount * 70) / 100;
            uint256 amountToB = amount - amountToA;

            if (amountToA > 0) poolA.deposit(amountToA);
            if (amountToB > 0) poolB.deposit(amountToB);
        } else {
            // 70% to B, 30% to A
            uint256 amountToB = (amount * 70) / 100;
            uint256 amountToA = amount - amountToB;

            if (amountToA > 0) poolA.deposit(amountToA);
            if (amountToB > 0) poolB.deposit(amountToB);
        }
    }

    /**
     * @notice Withdraw proportionally from pools
     * @param amount The total amount to withdraw
     */
    function _withdrawFromPools(uint256 amount) internal {
        uint256 poolAShares = poolA.sharesOf(address(this));
        uint256 poolBShares = poolB.sharesOf(address(this));

        uint256 poolAValue = poolA.convertToAssets(poolAShares);
        uint256 poolBValue = poolB.convertToAssets(poolBShares);
        uint256 total = poolAValue + poolBValue;

        if (total == 0) return;

        // Calculate proportional withdrawal from each pool
        uint256 fromA = (amount * poolAValue) / total;
        uint256 fromB = amount - fromA;

        // Withdraw from pools
        if (fromA > 0 && poolAValue > 0) {
            uint256 sharesToWithdraw = poolA.convertToShares(fromA);
            if (sharesToWithdraw > poolAShares) sharesToWithdraw = poolAShares;
            if (sharesToWithdraw > 0) poolA.withdraw(sharesToWithdraw);
        }

        if (fromB > 0 && poolBValue > 0) {
            uint256 sharesToWithdraw = poolB.convertToShares(fromB);
            if (sharesToWithdraw > poolBShares) sharesToWithdraw = poolBShares;
            if (sharesToWithdraw > 0) poolB.withdraw(sharesToWithdraw);
        }
    }

    /**
     * @notice Execute rebalance from one pool to another
     * @param fromPool The pool to withdraw from
     * @param toPool The pool to deposit to
     */
    function _rebalance(address fromPool, address toPool) internal {
        ILendingPool from = ILendingPool(fromPool);
        ILendingPool to = ILendingPool(toPool);

        uint256 fromShares = from.sharesOf(address(this));
        uint256 fromValue = from.convertToAssets(fromShares);

        if (fromValue == 0) return;

        // Calculate amount to move (based on rebalancePercentage)
        uint256 amountToMove = (fromValue * rebalancePercentage) / BPS;
        if (amountToMove == 0) return;

        // Calculate shares to withdraw
        uint256 sharesToWithdraw = from.convertToShares(amountToMove);
        if (sharesToWithdraw > fromShares) sharesToWithdraw = fromShares;
        if (sharesToWithdraw == 0) return;

        // Withdraw from source pool
        uint256 withdrawn = from.withdraw(sharesToWithdraw);

        // Deposit to destination pool
        if (withdrawn > 0) {
            to.deposit(withdrawn);
        }

        uint256 newRateA = poolA.getSupplyRate();
        uint256 newRateB = poolB.getSupplyRate();

        emit Rebalance(fromPool, toPool, withdrawn, newRateA, newRateB);
    }

    // ===== Owner Functions =====

    /**
     * @notice Set the authorized ReactVM address
     * @param _rvmId The ReactVM ID to authorize
     */
    function setAuthorizedReactVM(address _rvmId) external onlyOwner {
        emit AuthorizedReactVMUpdated(authorizedReactVM, _rvmId);
        authorizedReactVM = _rvmId;
    }

    /**
     * @notice Update rebalance threshold
     * @param _threshold New threshold in basis points
     */
    function setRebalanceThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Invalid threshold");
        emit ThresholdUpdated(rebalanceThreshold, _threshold);
        rebalanceThreshold = _threshold;
    }

    /**
     * @notice Update rebalance cooldown
     * @param _cooldown New cooldown in seconds
     */
    function setRebalanceCooldown(uint256 _cooldown) external onlyOwner {
        emit CooldownUpdated(rebalanceCooldown, _cooldown);
        rebalanceCooldown = _cooldown;
    }

    /**
     * @notice Update rebalance percentage
     * @param _percentage New percentage in basis points
     */
    function setRebalancePercentage(uint256 _percentage) external onlyOwner {
        require(_percentage <= BPS, "Invalid percentage");
        emit RebalancePercentageUpdated(rebalancePercentage, _percentage);
        rebalancePercentage = _percentage;
    }

    /**
     * @notice Emergency withdrawal by owner
     * @param token The token to withdraw
     * @param amount The amount to withdraw
     * @param to The recipient address
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Emergency full exit from pools
     */
    function emergencyExitPools() external onlyOwner {
        uint256 poolAShares = poolA.sharesOf(address(this));
        uint256 poolBShares = poolB.sharesOf(address(this));

        if (poolAShares > 0) poolA.withdraw(poolAShares);
        if (poolBShares > 0) poolB.withdraw(poolBShares);
    }

    // ===== Callback Payment Functions =====

    /// @notice Callback Proxy address on Sepolia
    address public constant CALLBACK_PROXY =
        0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA;

    /// @notice Allow the contract to receive ETH for paying callback fees
    receive() external payable {}

    /// @notice Allow the Callback Proxy to pull payment for callback gas costs
    /// @param amount The amount to pay
    function pay(uint256 amount) external {
        require(msg.sender == CALLBACK_PROXY, "Only callback proxy");
        require(address(this).balance >= amount, "Insufficient ETH balance");
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /// @notice Pay outstanding debt to the Callback Proxy
    /// @dev Anyone can call this to clear the vault's debt
    function coverDebt() external {
        // Query debt from callback proxy
        (bool success, bytes memory data) = CALLBACK_PROXY.call(
            abi.encodeWithSignature("debt(address)", address(this))
        );
        require(success, "Failed to query debt");
        uint256 debt = abi.decode(data, (uint256));

        require(address(this).balance >= debt, "Insufficient ETH for debt");
        if (debt > 0) {
            (bool paid, ) = payable(CALLBACK_PROXY).call{value: debt}("");
            require(paid, "Debt payment failed");
        }
    }

    /// @notice Withdraw ETH from the contract (owner only)
    /// @param amount Amount to withdraw
    /// @param to Recipient address
    function withdrawEth(uint256 amount, address to) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH");
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}
