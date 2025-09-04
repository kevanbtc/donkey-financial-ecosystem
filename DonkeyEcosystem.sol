// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/access/Ownable2Step.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/utils/math/Math.sol";

// ═══════════════════════════════════════════════════════════════════════════════
// CORE INFRASTRUCTURE - Circuit Breaker & KYC Registry
// ═══════════════════════════════════════════════════════════════════════════════

abstract contract CircuitBreaker is AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    bool public paused;
    
    event Paused(address account);
    event Unpaused(address account);
    
    modifier whenNotPaused() {
        require(!paused, "CircuitBreaker: paused");
        _;
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

contract KYCRegistry is Ownable2Step {
    struct Record {
        bool approved;
        bool blocked;
        uint16 countryCode;
        uint256 tier; // 0=basic, 1=premium, 2=institutional
    }
    
    mapping(address => Record) private _records;
    mapping(uint256 => uint256) public tierLimits; // tier -> daily limit in USD
    
    event RecordUpdated(address indexed user, bool approved, bool blocked, uint16 countryCode, uint256 tier);
    event TierLimitUpdated(uint256 tier, uint256 limit);
    
    constructor(address admin) {
        _transferOwnership(admin);
        // Set default tier limits (in USD with 18 decimals)
        tierLimits[0] = 10000 * 1e18;   // $10K daily limit for basic
        tierLimits[1] = 100000 * 1e18;  // $100K daily limit for premium
        tierLimits[2] = 1000000 * 1e18; // $1M daily limit for institutional
    }
    
    function setRecord(address user, bool approved, bool blocked, uint16 countryCode, uint256 tier) external onlyOwner {
        require(tier <= 2, "Invalid tier");
        _records[user] = Record(approved, blocked, countryCode, tier);
        emit RecordUpdated(user, approved, blocked, countryCode, tier);
    }
    
    function setTierLimit(uint256 tier, uint256 limit) external onlyOwner {
        require(tier <= 2, "Invalid tier");
        tierLimits[tier] = limit;
        emit TierLimitUpdated(tier, limit);
    }
    
    function isApproved(address user) external view returns (bool) {
        Record memory record = _records[user];
        return record.approved && !record.blocked;
    }
    
    function getUserTier(address user) external view returns (uint256) {
        return _records[user].tier;
    }
    
    function getDailyLimit(address user) external view returns (uint256) {
        return tierLimits[_records[user].tier];
    }
    
    function getRecord(address user) external view returns (bool approved, bool blocked, uint16 countryCode, uint256 tier) {
        Record memory record = _records[user];
        return (record.approved, record.blocked, record.countryCode, record.tier);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN SUITE - DUSD (Stablecoin) + WDONK (Governance) + DONK (Utility)
// ═══════════════════════════════════════════════════════════════════════════════

contract DonkeyUSD is ERC20, ERC20Permit, AccessControl, Ownable2Step, CircuitBreaker {
    using SafeERC20 for IERC20;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    // Reserves tracking for transparency (mirrors USD1)
    mapping(address => uint256) public reserves; // collateral -> amount
    address[] public collateralTokens;
    
    event Mint(address indexed to, uint256 amount, address collateral, uint256 collateralAmount);
    event Burn(address indexed from, uint256 amount);
    event ReserveUpdated(address indexed collateral, uint256 newAmount);
    
    constructor(address admin) 
        ERC20("Donkey USD", "DUSD") 
        ERC20Permit("Donkey USD") 
    {
        _transferOwnership(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }
    
    function addCollateral(address token) external onlyOwner {
        require(reserves[token] == 0, "Already added");
        collateralTokens.push(token);
        reserves[token] = 1; // Mark as active
        emit ReserveUpdated(token, 0);
    }
    
    function mint(address to, uint256 amount, address collateral, uint256 collateralAmount) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
    {
        require(reserves[collateral] > 0, "Invalid collateral");
        reserves[collateral] += collateralAmount;
        _mint(to, amount);
        emit Mint(to, amount, collateral, collateralAmount);
        emit ReserveUpdated(collateral, reserves[collateral]);
    }
    
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }
    
    function burnFrom(address from, uint256 amount) external onlyRole(BURNER_ROLE) whenNotPaused {
        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(from, msg.sender, currentAllowance - amount);
        _burn(from, amount);
        emit Burn(from, amount);
    }
    
    function getTotalReserves() external view returns (uint256 total) {
        for (uint i = 0; i < collateralTokens.length; i++) {
            total += reserves[collateralTokens[i]];
        }
    }
}

contract WorldDonkey is ERC20, ERC20Permit, AccessControl, Ownable2Step, CircuitBreaker {
    using SafeERC20 for IERC20;
    
    // Governance features (mirrors WLFI architecture)
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000000 * 1e18; // 1M WDONK to propose
    uint256 public constant QUORUM = 5; // 5% quorum
    
    // KYC enforcement (mirrors WLFI compliance)
    KYCRegistry public immutable kyc;
    
    // Non-transferable governance rights (like WLFI)
    mapping(address => bool) public canTransfer;
    
    event ProposalCreated(uint256 indexed id, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);
    event TransferabilityChanged(address indexed account, bool canTransfer);
    
    constructor(address admin, KYCRegistry _kyc) 
        ERC20("World Donkey", "WDONK") 
        ERC20Permit("World Donkey") 
    {
        require(address(_kyc) != address(0), "Zero KYC");
        _transferOwnership(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        kyc = _kyc;
        
        // Initially non-transferable except for admin
        canTransfer[admin] = true;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        require(!paused, "WDONK: paused");
        
        // KYC checks for both parties
        if (from != address(0)) {
            require(kyc.isApproved(from), "WDONK: from not approved");
        }
        if (to != address(0)) {
            require(kyc.isApproved(to), "WDONK: to not approved");
        }
        
        // Transferability checks (mirrors WLFI restrictions)
        if (from != address(0) && to != address(0)) {
            require(canTransfer[from] || canTransfer[to], "WDONK: non-transferable");
        }
        
        super._beforeTokenTransfer(from, to, amount);
    }
    
    function setTransferability(address account, bool _canTransfer) external onlyOwner {
        canTransfer[account] = _canTransfer;
        emit TransferabilityChanged(account, _canTransfer);
    }
    
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        require(totalSupply() + amount <= 100_000_000_000 * 1e18, "Max supply exceeded"); // 100B max like WLFI
        _mint(to, amount);
    }
    
    // Governance functions
    function propose(string memory description) external whenNotPaused returns (uint256) {
        require(balanceOf(msg.sender) >= PROPOSAL_THRESHOLD, "Below proposal threshold");
        require(kyc.isApproved(msg.sender), "Proposer not approved");
        
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        
        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }
    
    function vote(uint256 proposalId, uint8 support) external whenNotPaused {
        require(support <= 2, "Invalid vote type");
        require(kyc.isApproved(msg.sender), "Voter not approved");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Already executed");
        
        uint256 weight = balanceOf(msg.sender);
        require(weight > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        
        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumVotes = (totalSupply() * QUORUM) / 100;
        
        require(totalVotes >= quorumVotes, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");
        
        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }
}

contract DonkeyUtility is ERC20, ERC20Permit, AccessControl, CircuitBreaker {
    using SafeERC20 for IERC20;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Staking and rewards
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public lastRewardTime;
    mapping(address => uint256) public pendingRewards;
    
    uint256 public totalStaked;
    uint256 public rewardRate = 1000; // 10% APY (1000 = 10.00%)
    uint256 public constant REWARD_PRECISION = 10000;
    
    KYCRegistry public immutable kyc;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    
    constructor(address admin, KYCRegistry _kyc) 
        ERC20("Donkey Token", "DONK") 
        ERC20Permit("Donkey Token") 
    {
        require(address(_kyc) != address(0), "Zero KYC");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        kyc = _kyc;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        require(!paused, "DONK: paused");
        if (from != address(0)) {
            require(kyc.isApproved(from), "DONK: from not approved");
        }
        if (to != address(0)) {
            require(kyc.isApproved(to), "DONK: to not approved");
        }
        super._beforeTokenTransfer(from, to, amount);
    }
    
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }
    
    function stake(uint256 amount) external whenNotPaused {
        require(kyc.isApproved(msg.sender), "Not approved");
        require(amount > 0, "Zero amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _updateRewards(msg.sender);
        
        _transfer(msg.sender, address(this), amount);
        stakedAmount[msg.sender] += amount;
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    function unstake(uint256 amount) external whenNotPaused {
        require(stakedAmount[msg.sender] >= amount, "Insufficient staked");
        
        _updateRewards(msg.sender);
        
        stakedAmount[msg.sender] -= amount;
        totalStaked -= amount;
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    function claimRewards() external whenNotPaused {
        _updateRewards(msg.sender);
        
        uint256 rewards = pendingRewards[msg.sender];
        require(rewards > 0, "No rewards");
        
        pendingRewards[msg.sender] = 0;
        _mint(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards);
    }
    
    function _updateRewards(address user) internal {
        if (stakedAmount[user] > 0 && lastRewardTime[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime[user];
            uint256 rewards = (stakedAmount[user] * rewardRate * timeElapsed) / (365 days * REWARD_PRECISION);
            pendingRewards[user] += rewards;
        }
        lastRewardTime[user] = block.timestamp;
    }
    
    function setRewardRate(uint256 newRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRate <= 5000, "Rate too high"); // Max 50% APY
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }
    
    function getPendingRewards(address user) external view returns (uint256) {
        uint256 pending = pendingRewards[user];
        if (stakedAmount[user] > 0 && lastRewardTime[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime[user];
            uint256 newRewards = (stakedAmount[user] * rewardRate * timeElapsed) / (365 days * REWARD_PRECISION);
            pending += newRewards;
        }
        return pending;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEFI INFRASTRUCTURE - Lending/Borrowing (Aave V3 style)
// ═══════════════════════════════════════════════════════════════════════════════

contract DonkeyLendingPool is Ownable2Step, CircuitBreaker, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    struct ReserveData {
        address asset;
        uint256 totalSupply;
        uint256 totalBorrows;
        uint256 liquidityRate;
        uint256 borrowRate;
        uint256 lastUpdate;
        bool isActive;
        uint256 collateralFactor; // Basis points (7500 = 75%)
    }
    
    struct UserAccount {
        mapping(address => uint256) supplied;
        mapping(address => uint256) borrowed;
        uint256 lastUpdate;
    }
    
    mapping(address => ReserveData) public reserves;
    mapping(address => UserAccount) public accounts;
    mapping(address => bool) public isCollateral;
    
    address[] public reserveList;
    KYCRegistry public immutable kyc;
    
    uint256 public constant UTILIZATION_PRECISION = 10000;
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80%
    
    event Supply(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Liquidation(address indexed liquidator, address indexed borrower, address indexed asset, uint256 amount);
    
    constructor(address admin, KYCRegistry _kyc) {
        require(address(_kyc) != address(0), "Zero KYC");
        _transferOwnership(admin);
        _grantRole(PAUSER_ROLE, admin);
        kyc = _kyc;
    }
    
    function addReserve(
        address asset,
        uint256 collateralFactor
    ) external onlyOwner {
        require(reserves[asset].asset == address(0), "Reserve exists");
        require(collateralFactor <= 9000, "CF too high"); // Max 90%
        
        reserves[asset] = ReserveData({
            asset: asset,
            totalSupply: 0,
            totalBorrows: 0,
            liquidityRate: 200, // 2% base
            borrowRate: 400,    // 4% base
            lastUpdate: block.timestamp,
            isActive: true,
            collateralFactor: collateralFactor
        });
        
        reserveList.push(asset);
        isCollateral[asset] = true;
    }
    
    function supply(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(kyc.isApproved(msg.sender), "Not approved");
        require(reserves[asset].isActive, "Reserve inactive");
        require(amount > 0, "Zero amount");
        
        _updateInterest(asset);
        
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        accounts[msg.sender].supplied[asset] += amount;
        reserves[asset].totalSupply += amount;
        
        emit Supply(msg.sender, asset, amount);
    }
    
    function borrow(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(kyc.isApproved(msg.sender), "Not approved");
        require(reserves[asset].isActive, "Reserve inactive");
        require(amount > 0, "Zero amount");
        
        _updateInterest(asset);
        
        // Check collateral
        require(_isCollateralized(msg.sender, asset, amount), "Insufficient collateral");
        
        accounts[msg.sender].borrowed[asset] += amount;
        reserves[asset].totalBorrows += amount;
        
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        emit Borrow(msg.sender, asset, amount);
    }
    
    function repay(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(accounts[msg.sender].borrowed[asset] >= amount, "Repay too much");
        
        _updateInterest(asset);
        
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        accounts[msg.sender].borrowed[asset] -= amount;
        reserves[asset].totalBorrows -= amount;
        
        emit Repay(msg.sender, asset, amount);
    }
    
    function withdraw(address asset, uint256 amount) external nonReentrant whenNotPaused {
        require(accounts[msg.sender].supplied[asset] >= amount, "Withdraw too much");
        
        _updateInterest(asset);
        
        // Check if withdrawal leaves user properly collateralized
        accounts[msg.sender].supplied[asset] -= amount;
        require(_isHealthy(msg.sender), "Would be undercollateralized");
        
        reserves[asset].totalSupply -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, asset, amount);
    }
    
    function liquidate(
        address borrower,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover
    ) external nonReentrant whenNotPaused {
        require(!_isHealthy(borrower), "User healthy");
        require(accounts[borrower].borrowed[debtAsset] >= debtToCover, "Invalid debt amount");
        
        _updateInterest(debtAsset);
        _updateInterest(collateralAsset);
        
        // Calculate collateral to seize (with bonus)
        uint256 collateralToSeize = (debtToCover * 105) / 100; // 5% liquidation bonus
        require(accounts[borrower].supplied[collateralAsset] >= collateralToSeize, "Insufficient collateral");
        
        // Transfer debt token from liquidator
        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), debtToCover);
        
        // Update borrower's positions
        accounts[borrower].borrowed[debtAsset] -= debtToCover;
        accounts[borrower].supplied[collateralAsset] -= collateralToSeize;
        
        // Update reserves
        reserves[debtAsset].totalBorrows -= debtToCover;
        reserves[collateralAsset].totalSupply -= collateralToSeize;
        
        // Transfer collateral to liquidator
        IERC20(collateralAsset).safeTransfer(msg.sender, collateralToSeize);
        
        emit Liquidation(msg.sender, borrower, collateralAsset, collateralToSeize);
    }
    
    function _updateInterest(address asset) internal {
        ReserveData storage reserve = reserves[asset];
        uint256 timeElapsed = block.timestamp - reserve.lastUpdate;
        
        if (timeElapsed > 0 && reserve.totalSupply > 0) {
            uint256 utilization = (reserve.totalBorrows * UTILIZATION_PRECISION) / reserve.totalSupply;
            
            // Simple interest rate model
            reserve.borrowRate = 400 + (utilization * 2000) / UTILIZATION_PRECISION; // 4% + up to 20% based on utilization
            reserve.liquidityRate = (reserve.borrowRate * utilization) / UTILIZATION_PRECISION;
            
            reserve.lastUpdate = block.timestamp;
        }
    }
    
    function _isCollateralized(address user, address borrowAsset, uint256 borrowAmount) internal view returns (bool) {
        uint256 totalCollateralValue = 0;
        uint256 totalBorrowValue = 0;
        
        for (uint i = 0; i < reserveList.length; i++) {
            address asset = reserveList[i];
            
            if (accounts[user].supplied[asset] > 0) {
                uint256 collateralValue = accounts[user].supplied[asset] * reserves[asset].collateralFactor / 10000;
                totalCollateralValue += collateralValue;
            }
            
            if (accounts[user].borrowed[asset] > 0) {
                totalBorrowValue += accounts[user].borrowed[asset];
            }
        }
        
        // Add the new borrow
        if (borrowAsset != address(0)) {
            totalBorrowValue += borrowAmount;
        }
        
        return totalCollateralValue >= totalBorrowValue;
    }
    
    function _isHealthy(address user) internal view returns (bool) {
        uint256 totalCollateralValue = 0;
        uint256 totalBorrowValue = 0;
        
        for (uint i = 0; i < reserveList.length; i++) {
            address asset = reserveList[i];
            
            if (accounts[user].supplied[asset] > 0) {
                uint256 collateralValue = accounts[user].supplied[asset] * LIQUIDATION_THRESHOLD / 10000;
                totalCollateralValue += collateralValue;
            }
            
            if (accounts[user].borrowed[asset] > 0) {
                totalBorrowValue += accounts[user].borrowed[asset];
            }
        }
        
        return totalCollateralValue >= totalBorrowValue;
    }
    
    function getAccountData(address user) external view returns (
        uint256 totalSupplied,
        uint256 totalBorrowed,
        uint256 healthFactor
    ) {
        uint256 totalCollateralValue = 0;
        uint256 totalBorrowValue = 0;
        
        for (uint i = 0; i < reserveList.length; i++) {
            address asset = reserveList[i];
            totalSupplied += accounts[user].supplied[asset];
            totalBorrowed += accounts[user].borrowed[asset];
            
            if (accounts[user].supplied[asset] > 0) {
                uint256 collateralValue = accounts[user].supplied[asset] * LIQUIDATION_THRESHOLD / 10000;
                totalCollateralValue += collateralValue;
            }
            totalBorrowValue += accounts[user].borrowed[asset];
        }
        
        healthFactor = totalBorrowValue > 0 ? (totalCollateralValue * 1e18) / totalBorrowValue : type(uint256).max;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEX/AMM INFRASTRUCTURE - Uniswap V2 style
// ═══════════════════════════════════════════════════════════════════════════════

contract DonkeyDEX is Ownable2Step, CircuitBreaker, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    struct Pool {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        mapping(address => uint256) liquidityBalance;
        bool isActive;
    }
    
    mapping(bytes32 => Pool) public pools;
    bytes32[] public poolList;
    
    KYCRegistry public immutable kyc;
    uint256 public constant FEE_RATE = 30; // 0.3%
    uint256 public constant FEE_PRECISION = 10000;
    
    event PoolCreated(address indexed token0, address indexed token1, bytes32 poolId);
    event LiquidityAdded(address indexed user, bytes32 indexed poolId, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed user, bytes32 indexed poolId, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed user, bytes32 indexed poolId, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    
    constructor(address admin, KYCRegistry _kyc) {
        require(address(_kyc) != address(0), "Zero KYC");
        _transferOwnership(admin);
        _grantRole(PAUSER_ROLE, admin);
        kyc = _kyc;
    }
    
    function createPool(address token0, address token1) external onlyOwner returns (bytes32) {
        require(token0 != token1, "Same token");
        require(token0 != address(0) && token1 != address(0), "Zero address");
        
        // Order tokens
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1));
        require(pools[poolId].token0 == address(0), "Pool exists");
        
        pools[poolId].token0 = token0;
        pools[poolId].token1 = token1;
        pools[poolId].isActive = true;
        
        poolList.push(poolId);
        
        emit PoolCreated(token0, token1, poolId);
        return poolId;
    }
    
    function addLiquidity(
        bytes32 poolId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 liquidity) {
        require(kyc.isApproved(msg.sender), "Not approved");
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool inactive");
        
        uint256 amount0 = amount0Desired;
        uint256 amount1 = amount1Desired;
        
        if (pool.reserve0 > 0 && pool.reserve1 > 0) {
            uint256 amount1Optimal = (amount0Desired * pool.reserve1) / pool.reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient token1");
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * pool.reserve0) / pool.reserve1;
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min, "Insufficient token0");
                amount0 = amount0Optimal;
            }
        }
        
        if (pool.totalLiquidity == 0) {
            liquidity = Math.sqrt(amount0 * amount1);
        } else {
            liquidity = Math.min(
                (amount0 * pool.totalLiquidity) / pool.reserve0,
                (amount1 * pool.totalLiquidity) / pool.reserve1
            );
        }
        
        require(liquidity > 0, "Insufficient liquidity");
        
        IERC20(pool.token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(pool.token1).safeTransferFrom(msg.sender, address(this), amount1);
        
        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += liquidity;
        pool.liquidityBalance[msg.sender] += liquidity;
        
        emit LiquidityAdded(msg.sender, poolId, amount0, amount1, liquidity);
    }
    
    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        Pool storage pool = pools[poolId];
        require(pool.liquidityBalance[msg.sender] >= liquidity, "Insufficient liquidity");
        require(pool.totalLiquidity > 0, "No liquidity");
        
        amount0 = (liquidity * pool.reserve0) / pool.totalLiquidity;
        amount1 = (liquidity * pool.reserve1) / pool.totalLiquidity;
        
        require(amount0 >= amount0Min && amount1 >= amount1Min, "Insufficient amounts");
        
        pool.liquidityBalance[msg.sender] -= liquidity;
        pool.totalLiquidity -= liquidity;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        
        IERC20(pool.token0).safeTransfer(msg.sender, amount0);
        IERC20(pool.token1).safeTransfer(msg.sender, amount1);
        
        emit LiquidityRemoved(msg.sender, poolId, amount0, amount1, liquidity);
    }
    
    function swapExactTokensForTokens(
        bytes32 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(kyc.isApproved(msg.sender), "Not approved");
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool inactive");
        require(tokenIn == pool.token0 || tokenIn == pool.token1, "Invalid token");
        
        bool isToken0 = tokenIn == pool.token0;
        address tokenOut = isToken0 ? pool.token1 : pool.token0;
        uint256 reserveIn = isToken0 ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = isToken0 ? pool.reserve1 : pool.reserve0;
        
        // Calculate output with fee
        uint256 amountInWithFee = amountIn * (FEE_PRECISION - FEE_RATE) / FEE_PRECISION;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
        
        require(amountOut >= amountOutMin, "Insufficient output");
        require(amountOut < reserveOut, "Insufficient liquidity");
        
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        if (isToken0) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }
        
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        
        emit Swap(msg.sender, poolId, tokenIn, tokenOut, amountIn, amountOut);
    }
    
    function getAmountOut(bytes32 poolId, address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];
        require(tokenIn == pool.token0 || tokenIn == pool.token1, "Invalid token");
        
        bool isToken0 = tokenIn == pool.token0;
        uint256 reserveIn = isToken0 ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = isToken0 ? pool.reserve1 : pool.reserve0;
        
        if (reserveIn == 0 || reserveOut == 0) return 0;
        
        uint256 amountInWithFee = amountIn * (FEE_PRECISION - FEE_RATE) / FEE_PRECISION;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
    }
    
    function getPoolInfo(bytes32 poolId) external view returns (
        address token0,
        address token1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalLiquidity
    ) {
        Pool storage pool = pools[poolId];
        return (pool.token0, pool.token1, pool.reserve0, pool.reserve1, pool.totalLiquidity);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TREASURY MANAGEMENT - Protocol Revenue & Asset Management
// ═══════════════════════════════════════════════════════════════════════════════

contract DonkeyTreasury is Ownable2Step, CircuitBreaker {
    using SafeERC20 for IERC20;
    
    struct Asset {
        address token;
        uint256 balance;
        uint256 allocation; // Target allocation in basis points
        bool isActive;
    }
    
    mapping(address => Asset) public assets;
    address[] public assetList;
    
    // Protocol revenue tracking
    mapping(address => uint256) public protocolRevenue;
    uint256 public totalRevenueGenerated;
    
    // Fee distribution
    uint256 public constant TREASURY_FEE = 2000; // 20%
    uint256 public constant STAKER_FEE = 3000;   // 30%
    uint256 public constant BUYBACK_FEE = 2000;  // 20%
    uint256 public constant TEAM_FEE = 3000;     // 30%
    uint256 public constant FEE_PRECISION = 10000;
    
    address public teamWallet;
    address public stakingContract;
    DonkeyUtility public donkToken;
    
    event AssetAdded(address indexed token, uint256 allocation);
    event AssetRebalanced(address indexed token, uint256 oldBalance, uint256 newBalance);
    event RevenueDistributed(address indexed token, uint256 amount, uint256 treasury, uint256 stakers, uint256 buyback, uint256 team);
    event Buyback(address indexed token, uint256 amountIn, uint256 donkOut);
    
    constructor(
        address admin,
        address _teamWallet,
        address _stakingContract,
        DonkeyUtility _donkToken
    ) {
        require(_teamWallet != address(0), "Zero team wallet");
        require(_stakingContract != address(0), "Zero staking");
        require(address(_donkToken) != address(0), "Zero DONK");
        
        _transferOwnership(admin);
        _grantRole(PAUSER_ROLE, admin);
        
        teamWallet = _teamWallet;
        stakingContract = _stakingContract;
        donkToken = _donkToken;
    }
    
    function addAsset(address token, uint256 allocation) external onlyOwner {
        require(assets[token].token == address(0), "Asset exists");
        require(allocation <= 5000, "Allocation too high"); // Max 50%
        
        assets[token] = Asset({
            token: token,
            balance: 0,
            allocation: allocation,
            isActive: true
        });
        
        assetList.push(token);
        emit AssetAdded(token, allocation);
    }
    
    function receiveRevenue(address token, uint256 amount) external whenNotPaused {
        require(assets[token].isActive, "Asset inactive");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        protocolRevenue[token] += amount;
        totalRevenueGenerated += amount;
        
        // Distribute fees
        uint256 treasuryAmount = (amount * TREASURY_FEE) / FEE_PRECISION;
        uint256 stakerAmount = (amount * STAKER_FEE) / FEE_PRECISION;
        uint256 buybackAmount = (amount * BUYBACK_FEE) / FEE_PRECISION;
        uint256 teamAmount = (amount * TEAM_FEE) / FEE_PRECISION;
        
        // Keep treasury portion
        assets[token].balance += treasuryAmount;
        
        // Send to staking contract
        IERC20(token).safeTransfer(stakingContract, stakerAmount);
        
        // Send to team
        IERC20(token).safeTransfer(teamWallet, teamAmount);
        
        // Execute buyback if it's not DONK token
        if (token != address(donkToken)) {
            _executeBuyback(token, buybackAmount);
        } else {
            assets[token].balance += buybackAmount;
        }
        
        emit RevenueDistributed(token, amount, treasuryAmount, stakerAmount, buybackAmount, teamAmount);
    }
    
    function _executeBuyback(address token, uint256 amount) internal {
        // This would integrate with DonkeyDEX to swap for DONK and burn
        // For simplicity, we'll just track the buyback amount
        emit Buyback(token, amount, 0);
    }
    
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(assets[token].balance >= amount, "Insufficient balance");
        assets[token].balance -= amount;
        IERC20(token).safeTransfer(owner(), amount);
    }
    
    function rebalanceAsset(address token, uint256 newAmount) external onlyOwner {
        require(assets[token].isActive, "Asset inactive");
        
        uint256 oldBalance = assets[token].balance;
        assets[token].balance = newAmount;
        
        emit AssetRebalanced(token, oldBalance, newAmount);
    }
    
    function getTotalValue() external view returns (uint256 totalValue) {
        for (uint i = 0; i < assetList.length; i++) {
            address token = assetList[i];
            if (assets[token].isActive) {
                totalValue += assets[token].balance;
            }
        }
    }
    
    function getAssetAllocation(address token) external view returns (uint256 currentAllocation) {
        uint256 totalValue = this.getTotalValue();
        if (totalValue == 0) return 0;
        
        return (assets[token].balance * FEE_PRECISION) / totalValue;
    }
}