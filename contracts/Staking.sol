// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./types/AccessControlled.sol";

contract Staking is AccessControlled {
    // Staker info
    struct Staker {
        // The deposited tokens of the Staker
        uint256 deposited;
        // Last time of details update for Deposit
        uint256 timeOfLastUpdate;
        // Calculated, but unclaimed rewards. These are calculated each time
        // a user writes to the contract.
        uint256 unclaimedRewards;
    }

    // Rewards per hour. A fraction calculated as x/10.000.000 to get the percentage
    uint256 public rewardsPerHour = 285; // 0.00285%/h or 25% APR

    // Minimum amount to stake
    uint256 public minStake = 10_000_000; // 10,000,000 wei

    // Compounding frequency limit in seconds
    uint256 public compoundFreq = 60 * 60 * 24; // 24 hours

    // Mapping of address to Staker info
    mapping(address => Staker) internal stakers;

    // KonduxERC20 Contract
    IERC20 public konduxERC20;

    // Events
    event Withdraw(address indexed staker, uint256 amount);
    event Compound(address indexed staker, uint256 amount);
    event Stake(address indexed staker, uint256 amount);
    event Unstake(address indexed staker, uint256 amount);
    event Reward(address indexed staker, uint256 amount);


    // Constructor function
    constructor(address _authority, address _konduxERC20) 
        AccessControlled(IAuthority(_authority)) {        
            require(_konduxERC20 != address(0), "Kondux ERC20 address is not set");
            konduxERC20 = IERC20(_konduxERC20);
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
            stakers[msg.sender].timeOfLastUpdate = block.timestamp;
            stakers[msg.sender].unclaimedRewards = 0;
        } else {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
            stakers[msg.sender].deposited += _amount;
            stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        }
        konduxERC20.transferFrom(msg.sender, authority.vault(), _amount);
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
    function claimRewards() public {
        uint256 rewards = calculateRewards(msg.sender) + stakers[msg.sender].unclaimedRewards;
        require(rewards > 0, "You have no rewards");
        stakers[msg.sender].unclaimedRewards = 0;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        konduxERC20.transferFrom(authority.vault(), msg.sender, rewards);
        emit Reward(msg.sender, rewards);
    }

    // Withdraw specified amount of staked tokens
    function withdraw(uint256 _amount) public  {
        require(stakers[msg.sender].deposited >= _amount, "Can't withdraw more than you have");
        uint256 _rewards = calculateRewards(msg.sender);
        stakers[msg.sender].deposited -= _amount;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = _rewards;
        konduxERC20.transferFrom(authority.vault(), msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw all stake and rewards and mints them to the msg.sender
    function withdrawAll() public  {
        require(stakers[msg.sender].deposited > 0, "You have no deposit");
        uint256 _rewards = calculateRewards(msg.sender) + stakers[msg.sender].unclaimedRewards;
        uint256 _deposit = stakers[msg.sender].deposited;
        stakers[msg.sender].deposited = 0;
        stakers[msg.sender].timeOfLastUpdate = 0;
        uint256 _amount = _rewards + _deposit;
        konduxERC20.transferFrom(authority.vault(), msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
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
        return (((((block.timestamp - stakers[_staker].timeOfLastUpdate) * 
            stakers[_staker].deposited) * rewardsPerHour) / 3600) / 10000000); // blocks * staked * rewards/hour / 3600 / 10^7
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
}