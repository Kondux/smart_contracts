// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IHelix.sol";
import "./types/AccessControlled.sol";
import "hardhat/console.sol";

contract Staking is AccessControlled {
    // Staker info
    struct Staker {
        // The deposited tokens of the Staker
        uint256 deposited;
        // Last time of details update for Deposit
        uint256 timeOfLastUpdate;
        // Last deposit time
        uint256 lastDepositTime;
        // Calculated, but unclaimed rewards. These are calculated each time
        // a user writes to the contract.
        uint256 unclaimedRewards;
    }

    // Withdrawal fee in basis points
    uint256 public withdrawalFee = 100_000; // 1% fee on withdrawal or 100_000/10_000_000
    uint256 public withdrawalFeeDivisor = 10_000_000; // 10_000_000 basis points

    // Founder's reward boost in basis points
    uint256 public foundersRewardBoost = 1_000_000; // 10% boost on rewards or 1_000_000/10_000_000
    uint256 public foundersRewardBoostDivisor = 10_000_000; // 10_000_000 basis points

    // kNFT reward boost in basis points
    uint256 public kNFTRewardBoost = 100_000; // 1% boost on rewards or 100_000/10_000_000
    uint256 public kNFTRewardBoostDivisor = 10_000_000; // 10_000_000 basis points

    // Rewards per hour. A fraction calculated as x/10.000.000 to get the percentage
    // https://www.buybitcoinbank.com/crypto-apy-staking-calculator
    uint256 public rewardsPerHour = 285; // 0.00285%/h or 25% APR

    // Minimum amount to stake
    uint256 public minStake = 10_000_000; // 10,000,000 wei

    // Compounding frequency limit in seconds
    uint256 public compoundFreq = 60 * 60 * 24; // 24 hours
    // uint256 public compoundFreq = 60 * 60; // 1 hour
    // uint256 public compoundFreq = 60; // 1 minute // gives bugs when unstaking

    // Mapping of address to Staker info
    mapping(address => Staker) internal stakers;

    // Staked tokens minimum timelock
    uint256 public timelock = 60 * 60 * 24 * 1; // 1 days
    // uint256 public timelock = 60 * 60 * 2; // 2 hours
    // uint256 public timelock = 60 * 2; // 2 minutes


    // KonduxERC20 Contract
    IERC20 public konduxERC20;
    IHelix public helixERC20;
    IERC721 public konduxERC721Founders;
    IERC721 public konduxERC721kNFT;

    // Treasury Contract
    ITreasury public treasury;

    // Events
    event Withdraw(address indexed staker, uint256 amount);
    event Compound(address indexed staker, uint256 amount);
    event Stake(address indexed staker, uint256 amount);
    event Unstake(address indexed staker, uint256 amount);
    event Reward(address indexed staker, uint256 amount);


    // Constructor function
    constructor(address _authority, address _konduxERC20, address _treasury, address _konduxERC721Founders, address _konduxERC721kNFT, address _helixERC20)
        AccessControlled(IAuthority(_authority)) {        
            require(_konduxERC20 != address(0), "Kondux ERC20 address is not set");
            require(_treasury != address(0), "Treasury address is not set");
            konduxERC20 = IERC20(_konduxERC20);
            konduxERC721Founders = IERC721(_konduxERC721Founders);
            konduxERC721kNFT = IERC721(_konduxERC721kNFT);
            helixERC20 = IHelix(_helixERC20);
            treasury = ITreasury(_treasury);
    }

    modifier timelocked() {
        require(block.timestamp >= stakers[msg.sender].lastDepositTime + timelock, "Timelock not passed");
        _;
    }

    // If address has no Staker struct, initiate one. If address already was a stake,
    // calculate the rewards and add them to unclaimedRewards, reset the last time of
    // deposit and then add _amount to the already deposited amount.
    // Transfers the amount staked.
    function deposit(uint256 _amount) public {
        require(_amount >= minStake, "Amount smaller than minimimum deposit");
        require(konduxERC20.balanceOf(msg.sender) >= _amount, "Can't stake more than you own");
        if (stakers[msg.sender].deposited == 0) {
            stakers[msg.sender].deposited = _amount;
            stakers[msg.sender].unclaimedRewards = 0;
        } else {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
            stakers[msg.sender].deposited += _amount;            
        }
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].lastDepositTime = block.timestamp;
        konduxERC20.transferFrom(msg.sender, authority.vault(), _amount);
        helixERC20.mint(msg.sender, _amount);
        emit Stake(msg.sender, _amount);
    }

    // Compound the rewards and reset the last time of update for Deposit info
    function stakeRewards() public {
        require(stakers[msg.sender].deposited > 0, "You have no deposit");
        require(compoundRewardsTimer(msg.sender) == 0, "Tried to compound rewards too soon");
        uint256 rewards = calculateRewards(msg.sender) + stakers[msg.sender].unclaimedRewards;
        stakers[msg.sender].unclaimedRewards = 0;
        stakers[msg.sender].deposited += rewards;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        emit Compound(msg.sender, rewards);
    }

    // Transfer rewards to msg.sender
    function claimRewards() public timelocked {
        console.log("Claiming rewards");
        // console.log("staking contract address", address(this));

        uint256 rewards = calculateRewards(msg.sender) + stakers[msg.sender].unclaimedRewards;
        console.log("rewards: %s", rewards);
        console.log("pre-claiming balance vault: %s", konduxERC20.balanceOf(authority.vault()));
        console.log("ERC20 address: %s", address(konduxERC20));
        require(rewards > 0, "You have no rewards");
        stakers[msg.sender].unclaimedRewards = 0;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        konduxERC20.transferFrom(authority.vault(), msg.sender, rewards);
        // console.logString("Rewards claimed");
        // console.log(konduxERC20.balanceOf(authority.vault()));
        emit Reward(msg.sender, rewards);
    }

    // Withdraw specified amount of staked tokens
    function withdraw(uint256 _amount) public timelocked {
        require(stakers[msg.sender].deposited >= _amount, "Can't withdraw more than you have");
        require(_amount >= helixERC20.balanceOf(msg.sender), "Can't withdraw more tokens than the collateral you have");
        uint256 _rewards = calculateRewards(msg.sender);
        stakers[msg.sender].deposited -= _amount;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = _rewards;
        uint256 _liquid = (_amount * withdrawalFee) / withdrawalFeeDivisor;
        helixERC20.burn(msg.sender, _amount);
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);
        emit Withdraw(msg.sender, _liquid);
    }

    // Withdraw all stake and rewards and mints them to the msg.sender
    function withdrawAll() public timelocked {
        require(stakers[msg.sender].deposited > 0, "You have no deposit");
        uint256 _rewards = calculateRewards(msg.sender) + stakers[msg.sender].unclaimedRewards;
        uint256 _deposit = stakers[msg.sender].deposited;
        stakers[msg.sender].deposited = 0;
        stakers[msg.sender].timeOfLastUpdate = 0;
        uint256 _amount = _rewards + _deposit;
        require(_amount >= helixERC20.balanceOf(msg.sender), "Can't withdraw more tokens than the collateral you have");
        uint256 _liquid = (_amount * withdrawalFee) / withdrawalFeeDivisor;
        helixERC20.burn(msg.sender, _amount);
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);
        emit Withdraw(msg.sender, _liquid);
    }

    // Function useful for fron-end that returns user stake and rewards by address
    function getDepositInfo(address _user) public view returns (uint256 _stake, uint256 _rewards) {
        _stake = stakers[_user].deposited;
        _rewards = calculateRewards(_user) + stakers[msg.sender].unclaimedRewards;
        return (_stake, _rewards);
    }

    // Utility function that returns the timer for restaking rewards
    function compoundRewardsTimer(address _user) public view returns (uint256 _timer) {
        if (stakers[_user].timeOfLastUpdate + compoundFreq <= block.timestamp) {
            return 0;
        } else {
            return (stakers[_user].timeOfLastUpdate + compoundFreq) - block.timestamp;
        }
    }

    // Calculate the rewards since the last update on Deposit info
    function calculateRewards(address _staker) public view returns (uint256 rewards) {
        console.log("Calculating rewards");
        console.log("stakers[_staker].timeOfLastUpdate: %s", stakers[_staker].timeOfLastUpdate);
        console.log("block.timestamp: %s", block.timestamp);
        console.log("stakers[_staker].deposited: %s", stakers[_staker].deposited);
        console.log("rewardsPerHour: %s", rewardsPerHour);
        console.log("((((block.timestamp - stakers[_staker].timeOfLastUpdate) * stakers[_staker].deposited) * rewardsPerHour) / 3600) / 10_000_000: %s", ((((block.timestamp - stakers[_staker].timeOfLastUpdate) * stakers[_staker].deposited) * rewardsPerHour) / 3600) / 10_000_000);

        uint256 _reward = (((((block.timestamp - stakers[_staker].timeOfLastUpdate) * 
            stakers[_staker].deposited) * rewardsPerHour) / 3600) / 10_000_000); // blocks * staked * rewards/hour / 1h / 10^7

        console.log("reward: %s", _reward);
        
        if (IERC721(konduxERC721Founders).balanceOf(_staker) > 0) {
            _reward = (_reward * foundersRewardBoost) / foundersRewardBoostDivisor;
            console.log("reward after founders: %s", _reward);
        }

        if (IERC721(konduxERC721kNFT).balanceOf(_staker) > 0) {
            uint256 _kNFTBalance = IERC721(konduxERC721kNFT).balanceOf(_staker);
            if (_kNFTBalance > 5) {
                _kNFTBalance = 5;
            }
            _reward = _reward * (kNFTRewardBoost + (5 * _kNFTBalance)) / kNFTRewardBoostDivisor;
            console.log("reward after kNFT: %s", _reward);
        }

        return _reward;
    }

    // Functions for modifying  staking mechanism variables:

    // Set rewards per hour as x/10.000.000 (Example: 100.000 = 1%)
    function setRewards(uint256 _rewardsPerHour) public onlyGovernor {
        rewardsPerHour = _rewardsPerHour;
    }

    // Set the minimum amount for staking in wei
    function setMinStake(uint256 _minStake) public onlyGovernor {
        minStake = _minStake;
    }

    // Set the minimum time that has to pass for a user to be able to restake rewards
    function setCompFreq(uint256 _compoundFreq) public onlyGovernor {
        compoundFreq = _compoundFreq;
    }

    // Set the address of the Kondux ERC20 token
    function setKonduxERC20(address _konduxERC20) public onlyGovernor {
        konduxERC20 = IERC20(_konduxERC20);
    }

    // Set the address of Helix Contract
    function setHelixERC20(address _helix) public onlyGovernor {
        helixERC20 = IHelix(_helix);
    }

    // Set the address of konduxERC721Founders contract
    function setKonduxERC721Founders(address _konduxERC721Founders) public onlyGovernor {
        konduxERC721Founders = IERC721(_konduxERC721Founders);
    }

    // Set the address of konduxERC721kNFT contract
    function setKonduxERC721kNFT(address _konduxERC721kNFT) public onlyGovernor {
        konduxERC721kNFT = IERC721(_konduxERC721kNFT);
    }

    // Set the address of the Treasury contract
    function setTreasury(address _treasury) public onlyGovernor {
        treasury = ITreasury(_treasury);
    }

    // Set the time lock for withdraw and claim functions
    function setTimeLock(uint256 _timelock) public onlyGovernor {
        timelock = _timelock;        
    }

    // Set the withdrawal fee
    function setWithdrawalFee(uint256 _withdrawalFee) public onlyGovernor {
        withdrawalFee = _withdrawalFee;
    }

    // Set the withdrawal fee divisor
    function setWithdrawalFeeDivisor(uint256 _withdrawalFeeDivisor) public onlyGovernor {
        withdrawalFeeDivisor = _withdrawalFeeDivisor;
    }

    // Set the founders reward boost
    function setFoundersRewardBoost(uint256 _foundersRewardBoost) public onlyGovernor {
        foundersRewardBoost = _foundersRewardBoost;
    }

    // Set the founders reward boost divisor
    function setFoundersRewardBoostDivisor(uint256 _foundersRewardBoostDivisor) public onlyGovernor {
        foundersRewardBoostDivisor = _foundersRewardBoostDivisor;
    }

    // Set the kNFT reward boost
    function setkNFTRewardBoost(uint256 _kNFTRewardBoost) public onlyGovernor {
        kNFTRewardBoost = _kNFTRewardBoost;
    }

    // Set the kNFT reward boost divisor
    function setkNFTRewardBoostDivisor(uint256 _kNFTRewardBoostDivisor) public onlyGovernor {
        kNFTRewardBoostDivisor = _kNFTRewardBoostDivisor;
    }

    // Functions for getting staking mechanism variables:

    // Get staker's time of last update
    function getTimeOfLastUpdate(address _staker) public view returns (uint256 _timeOfLastUpdate) {
        return stakers[_staker].timeOfLastUpdate;
    }

    // Get staker's deposited amount
    function getStakedAmount(address _staker) public view returns (uint256 _deposited) {
        return stakers[_staker].deposited;
    }

    // Get rewards per hour
    function getRewardsPerHour() public view returns (uint256 _rewardsPerHour) {
        return rewardsPerHour;
    }

    // Get Founder's reward boost
    function getFoundersRewardBoost() public view returns (uint256 _foundersRewardBoost) {
        return foundersRewardBoost;
    }

    // Get Founder's reward boost divisor
    function getFoundersRewardBoostDenominator() public view returns (uint256 _foundersRewardBoostDivisor) {
        return foundersRewardBoostDivisor;
    }

    // Get kNFT reward boost
    function getkNFTRewardBoost() public view returns (uint256 _kNFTRewardBoost) {
        return kNFTRewardBoost;
    }

    // Get kNFT reward boost divisor
    function getKnftRewardBoostDenominator() public view returns (uint256 _kNFTRewardBoostDivisor) {
        return kNFTRewardBoostDivisor;
    }

    // Get minimum stake
    function getMinStake() public view returns (uint256 _minStake) {
        return minStake;
    }
}