// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/access/Ownable2Step.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/token/ERC20/IERC20.sol";

abstract contract CircuitBreaker is AccessControl {
    using SafeERC20 for IERC20;
    
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
    }
    
    mapping(address => Record) private _records;
    
    event RecordUpdated(address indexed user, bool approved, bool blocked, uint16 countryCode);
    
    constructor(address admin) {
        _transferOwnership(admin);
    }
    
    function setRecord(address user, bool approved, bool blocked, uint16 countryCode) external onlyOwner {
        _records[user] = Record(approved, blocked, countryCode);
        emit RecordUpdated(user, approved, blocked, countryCode);
    }
    
    function isApproved(address user) external view returns (bool) {
        Record memory record = _records[user];
        return record.approved && !record.blocked;
    }
    
    function getRecord(address user) external view returns (bool approved, bool blocked, uint16 countryCode) {
        Record memory record = _records[user];
        return (record.approved, record.blocked, record.countryCode);
    }
}

contract DonkeyStable is ERC20, ERC20Permit, AccessControl, Ownable2Step, CircuitBreaker {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    constructor(address admin) 
        ERC20("Donkey USD", "DUSD") 
        ERC20Permit("Donkey USD") 
    {
        _transferOwnership(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }
    
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
        emit Mint(to, amount);
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
}

contract DonkeyVault is Ownable2Step, CircuitBreaker {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable collateral;
    DonkeyStable public immutable dusd;
    
    event Deposited(address indexed user, uint256 collateralIn, uint256 dusdOut);
    event Redeemed(address indexed user, uint256 dusdIn, uint256 collateralOut);
    
    constructor(address admin, IERC20 _collateral, DonkeyStable _dusd) {
        require(address(_collateral) != address(0), "DonkeyVault: zero collateral");
        require(address(_dusd) != address(0), "DonkeyVault: zero dusd");
        _transferOwnership(admin);
        _grantRole(PAUSER_ROLE, admin);
        collateral = _collateral;
        dusd = _dusd;
    }
    
    function depositAndMint(uint256 amount) external whenNotPaused {
        require(amount > 0, "DonkeyVault: zero amount");
        
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        
        // Collateral is 6 decimals, DUSD is 18 decimals
        uint256 dusdAmount = amount * 1e12;
        dusd.mint(msg.sender, dusdAmount);
        
        emit Deposited(msg.sender, amount, dusdAmount);
    }
    
    function redeem(uint256 dusdAmount) external whenNotPaused {
        require(dusdAmount > 0, "DonkeyVault: zero amount");
        
        // DUSD is 18 decimals, collateral is 6 decimals
        uint256 collateralAmount = dusdAmount / 1e12;
        require(collateralAmount > 0, "DonkeyVault: amount too small");
        
        dusd.burnFrom(msg.sender, dusdAmount);
        collateral.safeTransfer(msg.sender, collateralAmount);
        
        emit Redeemed(msg.sender, dusdAmount, collateralAmount);
    }
    
    function getCollateralBalance() external view returns (uint256) {
        return collateral.balanceOf(address(this));
    }
}

contract DonkeySecurityToken is ERC20, ERC20Snapshot, Ownable2Step, CircuitBreaker {
    using SafeERC20 for IERC20;
    
    KYCRegistry public immutable kyc;
    DonkeyStable public immutable payoutToken;
    
    struct Distribution {
        uint256 snapshotId;
        uint256 totalAmount;
        bool active;
        mapping(address => bool) claimed;
    }
    
    mapping(uint256 => Distribution) public distributions;
    uint256 public distributionCount;
    
    event DistributionCreated(uint256 indexed id, uint256 snapshotId, uint256 totalAmount);
    event Claimed(address indexed user, uint256 indexed distributionId, uint256 amount);
    
    constructor(
        address admin,
        KYCRegistry _kyc,
        DonkeyStable _payoutToken,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        require(address(_kyc) != address(0), "DonkeySecurityToken: zero kyc");
        require(address(_payoutToken) != address(0), "DonkeySecurityToken: zero payout token");
        _transferOwnership(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        kyc = _kyc;
        payoutToken = _payoutToken;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        require(!paused, "DonkeySecurityToken: paused");
        if (from != address(0)) {
            require(kyc.isApproved(from), "DonkeySecurityToken: from not approved");
        }
        if (to != address(0)) {
            require(kyc.isApproved(to), "DonkeySecurityToken: to not approved");
        }
        super._beforeTokenTransfer(from, to, amount);
    }
    
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        _mint(to, amount);
    }
    
    function createDistribution(uint256 amountDUSD) external onlyOwner whenNotPaused {
        require(amountDUSD > 0, "DonkeySecurityToken: zero amount");
        require(totalSupply() > 0, "DonkeySecurityToken: no tokens");
        
        payoutToken.transferFrom(msg.sender, address(this), amountDUSD);
        
        uint256 snapshotId = _snapshot();
        uint256 distributionId = distributionCount++;
        
        Distribution storage dist = distributions[distributionId];
        dist.snapshotId = snapshotId;
        dist.totalAmount = amountDUSD;
        dist.active = true;
        
        emit DistributionCreated(distributionId, snapshotId, amountDUSD);
    }
    
    function claim(uint256 distributionId) external whenNotPaused {
        Distribution storage dist = distributions[distributionId];
        require(dist.active, "DonkeySecurityToken: inactive distribution");
        require(!dist.claimed[msg.sender], "DonkeySecurityToken: already claimed");
        
        uint256 userBalance = balanceOfAt(msg.sender, dist.snapshotId);
        require(userBalance > 0, "DonkeySecurityToken: no tokens at snapshot");
        
        uint256 totalSupplyAtSnapshot = totalSupplyAt(dist.snapshotId);
        uint256 claimAmount = (userBalance * dist.totalAmount) / totalSupplyAtSnapshot;
        
        dist.claimed[msg.sender] = true;
        payoutToken.safeTransfer(msg.sender, claimAmount);
        
        emit Claimed(msg.sender, distributionId, claimAmount);
    }
    
    function getClaimableAmount(uint256 distributionId, address user) external view returns (uint256) {
        Distribution storage dist = distributions[distributionId];
        if (!dist.active || dist.claimed[user]) {
            return 0;
        }
        
        uint256 userBalance = balanceOfAt(user, dist.snapshotId);
        if (userBalance == 0) {
            return 0;
        }
        
        uint256 totalSupplyAtSnapshot = totalSupplyAt(dist.snapshotId);
        return (userBalance * dist.totalAmount) / totalSupplyAtSnapshot;
    }
    
    function hasClaimed(uint256 distributionId, address user) external view returns (bool) {
        return distributions[distributionId].claimed[user];
    }
}