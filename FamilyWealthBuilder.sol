// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Family Wealth Builder - White Label Infrastructure
 * @dev Simple, automated wealth-building system for the Kizer family
 * Built on the Web3 Construction OS foundation with family-friendly interfaces
 */

// Simple KYC Registry - Just send link, they fill form, auto-approved
contract SimpleKYC is Ownable {
    mapping(address => bool) public verified;
    mapping(address => string) public names;
    mapping(string => address) public nameToAddress;
    
    event PersonVerified(address indexed person, string name);
    
    // Super simple - just add people by name
    function addFamilyMember(address person, string memory name) external onlyOwner {
        verified[person] = true;
        names[person] = name;
        nameToAddress[name] = person;
        emit PersonVerified(person, name);
    }
    
    // Anyone can check if someone is verified
    function isVerified(address person) external view returns (bool) {
        return verified[person];
    }
}

// Family Wealth Token - Represents ownership in all family businesses
contract FamilyWealthToken is ERC20, Ownable {
    SimpleKYC public kyc;
    uint256 public totalRevenue;
    uint256 public lastDistributionTime;
    
    mapping(address => uint256) public lastClaimTime;
    
    event RevenueAdded(uint256 amount, string source);
    event DividendsClaimed(address indexed holder, uint256 amount);
    
    constructor(address _kyc) ERC20("Kizer Family Wealth", "KFW") {
        kyc = SimpleKYC(_kyc);
        _mint(owner(), 1000000 * 10**18); // 1M tokens for family distribution
    }
    
    // Only verified family members can hold tokens
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(kyc.isVerified(to), "Recipient not verified");
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(kyc.isVerified(to), "Recipient not verified");
        return super.transferFrom(from, to, amount);
    }
    
    // Add revenue from construction projects, gold trading, etc.
    function addRevenue(uint256 amount, string memory source) external onlyOwner {
        totalRevenue += amount;
        emit RevenueAdded(amount, source);
    }
    
    // Calculate dividends per token
    function dividendsPerToken() public view returns (uint256) {
        if (totalSupply() == 0) return 0;
        return (totalRevenue * 1e18) / totalSupply();
    }
    
    // Claim your share of profits automatically
    function claimDividends() external {
        require(kyc.isVerified(msg.sender), "Not verified");
        require(balanceOf(msg.sender) > 0, "No tokens");
        
        uint256 owed = (balanceOf(msg.sender) * dividendsPerToken()) / 1e18;
        uint256 claimed = (balanceOf(msg.sender) * (totalRevenue * 1e18) / totalSupply()) / 1e18;
        
        // Calculate what they haven't claimed yet
        uint256 toClaim = owed; // Simplified for demo
        require(toClaim > 0, "Nothing to claim");
        
        // Send ETH dividends
        payable(msg.sender).transfer(toClaim);
        emit DividendsClaimed(msg.sender, toClaim);
    }
    
    // Owner can deposit ETH for dividends
    receive() external payable {
        totalRevenue += msg.value;
        emit RevenueAdded(msg.value, "Direct deposit");
    }
}

// Instant Settlement Engine for Construction Projects
contract FamilyConstructionSettlement is ReentrancyGuard, Ownable {
    FamilyWealthToken public familyToken;
    
    struct Project {
        string name;
        uint256 totalValue;
        uint256 familyFee; // Our cut (usually 5-10%)
        address contractor;
        bool completed;
        bool settled;
    }
    
    mapping(uint256 => Project) public projects;
    uint256 public projectCount;
    uint256 public totalEarnings;
    
    event ProjectAdded(uint256 indexed projectId, string name, uint256 value, uint256 familyFee);
    event ProjectSettled(uint256 indexed projectId, uint256 familyEarnings);
    
    constructor(address _familyToken) {
        familyToken = FamilyWealthToken(_familyToken);
    }
    
    // Add a new construction project
    function addProject(
        string memory name,
        uint256 totalValue,
        uint256 feePercentage, // e.g., 750 = 7.5%
        address contractor
    ) external onlyOwner returns (uint256) {
        uint256 projectId = projectCount++;
        uint256 familyFee = (totalValue * feePercentage) / 10000;
        
        projects[projectId] = Project({
            name: name,
            totalValue: totalValue,
            familyFee: familyFee,
            contractor: contractor,
            completed: false,
            settled: false
        });
        
        emit ProjectAdded(projectId, name, totalValue, familyFee);
        return projectId;
    }
    
    // Settle project - pays contractor and takes family fee
    function settleProject(uint256 projectId) external payable nonReentrant {
        Project storage project = projects[projectId];
        require(!project.settled, "Already settled");
        require(msg.value >= project.totalValue, "Insufficient payment");
        
        // Pay contractor
        uint256 contractorPayment = project.totalValue - project.familyFee;
        payable(project.contractor).transfer(contractorPayment);
        
        // Add family earnings to wealth token
        familyToken.addRevenue{value: project.familyFee}(project.familyFee, project.name);
        
        project.completed = true;
        project.settled = true;
        totalEarnings += project.familyFee;
        
        emit ProjectSettled(projectId, project.familyFee);
    }
}

// Gold Trading Fund - Simplified Teucrium-style
contract FamilyGoldFund is ERC20, ReentrancyGuard, Ownable {
    SimpleKYC public kyc;
    
    uint256 public goldPriceUSD; // Price per gram in USD (with 18 decimals)
    uint256 public totalGoldGrams;
    uint256 public managementFeePercent = 150; // 1.5% annual
    uint256 public lastFeeCollection;
    
    mapping(address => uint256) public goldDeposits; // Track individual deposits
    
    event GoldDeposited(address indexed depositor, uint256 grams, uint256 shares);
    event GoldWithdrawn(address indexed withdrawer, uint256 shares, uint256 grams);
    event GoldPriceUpdated(uint256 newPrice);
    
    constructor(address _kyc) ERC20("Kizer Family Gold", "KFG") {
        kyc = SimpleKYC(_kyc);
        lastFeeCollection = block.timestamp;
    }
    
    // Only verified family can hold shares
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(kyc.isVerified(to), "Recipient not verified");
        return super.transfer(to, amount);
    }
    
    // Update gold price (would connect to Chainlink in production)
    function updateGoldPrice(uint256 priceUSD) external onlyOwner {
        goldPriceUSD = priceUSD;
        emit GoldPriceUpdated(priceUSD);
    }
    
    // Deposit gold and get shares
    function depositGold(uint256 grams) external payable nonReentrant {
        require(kyc.isVerified(msg.sender), "Not verified");
        require(grams > 0, "Must deposit gold");
        
        // Calculate shares to mint (1:1 with grams for simplicity)
        uint256 sharesToMint = grams * 1e18;
        
        totalGoldGrams += grams;
        goldDeposits[msg.sender] += grams;
        _mint(msg.sender, sharesToMint);
        
        emit GoldDeposited(msg.sender, grams, sharesToMint);
    }
    
    // Withdraw gold by burning shares
    function withdrawGold(uint256 shares) external nonReentrant {
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");
        
        uint256 grams = shares / 1e18;
        require(grams <= totalGoldGrams, "Insufficient gold reserves");
        
        totalGoldGrams -= grams;
        goldDeposits[msg.sender] -= grams;
        _burn(msg.sender, shares);
        
        // In real implementation, this would trigger physical gold delivery
        emit GoldWithdrawn(msg.sender, shares, grams);
    }
    
    // Get current net asset value per share
    function navPerShare() external view returns (uint256) {
        if (totalSupply() == 0) return goldPriceUSD;
        return (totalGoldGrams * goldPriceUSD) / (totalSupply() / 1e18);
    }
    
    // Collect management fees
    function collectManagementFee() external {
        uint256 timePassed = block.timestamp - lastFeeCollection;
        uint256 annualFeeAmount = (totalSupply() * managementFeePercent) / 10000;
        uint256 feeAmount = (annualFeeAmount * timePassed) / 365 days;
        
        if (feeAmount > 0) {
            _mint(owner(), feeAmount);
            lastFeeCollection = block.timestamp;
        }
    }
}

// Simple Onboarding System
contract FamilyOnboarding is Ownable {
    SimpleKYC public kyc;
    FamilyWealthToken public wealthToken;
    
    struct OnboardingRequest {
        address user;
        string name;
        string email;
        bool approved;
        uint256 welcomeTokens;
    }
    
    mapping(address => OnboardingRequest) public requests;
    mapping(string => bool) public usedEmails;
    
    event OnboardingRequested(address indexed user, string name, string email);
    event OnboardingApproved(address indexed user, uint256 welcomeTokens);
    
    constructor(address _kyc, address _wealthToken) {
        kyc = SimpleKYC(_kyc);
        wealthToken = FamilyWealthToken(_wealthToken);
    }
    
    // Super simple - just submit name and email
    function requestOnboarding(string memory name, string memory email) external {
        require(!usedEmails[email], "Email already used");
        require(bytes(name).length > 0, "Name required");
        
        requests[msg.sender] = OnboardingRequest({
            user: msg.sender,
            name: name,
            email: email,
            approved: false,
            welcomeTokens: 100 * 1e18 // 100 tokens as welcome gift
        });
        
        usedEmails[email] = true;
        emit OnboardingRequested(msg.sender, name, email);
    }
    
    // Owner approves and user gets instant access
    function approveOnboarding(address user) external onlyOwner {
        OnboardingRequest storage request = requests[user];
        require(!request.approved, "Already approved");
        
        // Add to KYC
        kyc.addFamilyMember(user, request.name);
        
        // Give welcome tokens
        wealthToken.transfer(user, request.welcomeTokens);
        
        request.approved = true;
        emit OnboardingApproved(user, request.welcomeTokens);
    }
}

// Master Controller - The "Sit Back and Collect" Interface
contract FamilyWealthMaster is Ownable, Pausable {
    SimpleKYC public kyc;
    FamilyWealthToken public wealthToken;
    FamilyConstructionSettlement public constructionSettlement;
    FamilyGoldFund public goldFund;
    FamilyOnboarding public onboarding;
    
    struct RevenueStream {
        string name;
        uint256 totalEarned;
        uint256 monthlyAverage;
        bool active;
    }
    
    mapping(string => RevenueStream) public revenueStreams;
    string[] public streamNames;
    
    event RevenueStreamAdded(string name, uint256 amount);
    event AutomatedDistribution(uint256 totalAmount, uint256 holders);
    
    constructor() {
        // Will be initialized after other contracts are deployed
    }
    
    function initialize(
        address _kyc,
        address _wealthToken,
        address _constructionSettlement,
        address _goldFund,
        address _onboarding
    ) external onlyOwner {
        kyc = SimpleKYC(_kyc);
        wealthToken = FamilyWealthToken(_wealthToken);
        constructionSettlement = FamilyConstructionSettlement(_constructionSettlement);
        goldFund = FamilyGoldFund(_goldFund);
        onboarding = FamilyOnboarding(_onboarding);
    }
    
    // Add revenue from any source
    function addRevenue(string memory source, uint256 amount) external payable onlyOwner {
        if (!streamExists(source)) {
            revenueStreams[source] = RevenueStream({
                name: source,
                totalEarned: 0,
                monthlyAverage: 0,
                active: true
            });
            streamNames.push(source);
        }
        
        revenueStreams[source].totalEarned += amount;
        wealthToken.addRevenue{value: amount}(amount, source);
        
        emit RevenueStreamAdded(source, amount);
    }
    
    // Automated wealth distribution to all family members
    function distributeWealth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to distribute");
        
        // Count verified family members
        uint256 familyCount = wealthToken.totalSupply() > 0 ? 
            countFamilyMembers() : 0;
        
        if (familyCount > 0) {
            wealthToken.addRevenue{value: balance}(balance, "Automated Distribution");
            emit AutomatedDistribution(balance, familyCount);
        }
    }
    
    // Get total family wealth
    function getTotalFamilyWealth() external view returns (uint256) {
        return wealthToken.totalRevenue() + goldFund.totalSupply() + 
               constructionSettlement.totalEarnings();
    }
    
    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Helper functions
    function streamExists(string memory name) internal view returns (bool) {
        return bytes(revenueStreams[name].name).length > 0;
    }
    
    function countFamilyMembers() internal view returns (uint256) {
        // Simplified - in production would iterate through verified addresses
        return 10; // Placeholder
    }
    
    // Accept payments from any source
    receive() external payable {
        // Auto-add to general revenue
        wealthToken.addRevenue{value: msg.value}(msg.value, "Direct Payment");
    }
}