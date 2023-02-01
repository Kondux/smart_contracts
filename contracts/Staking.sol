// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IHelix.sol";
import "./types/AccessControlled.sol";
import "hardhat/console.sol";

contract Staking is AccessControlled {
    using Counters for Counters.Counter;

    Counters.Counter private _depositIds;

    // Staker info
    struct Staker {
        address staker;
        // The deposited tokens of the Staker
        uint256 deposited;
        uint256 redeemed;
        // Last time of details update for Deposit
        uint256 timeOfLastUpdate;
        // Last deposit time
        uint256 lastDepositTime;
        // Calculated, but unclaimed rewards. These are calculated each time
        // a user writes to the contract.
        uint256 unclaimedRewards;
        uint256 timelock;
        uint8 timelockCategory;
    }

    enum LockingTimes {        
        OneMonth,
        ThreeMonths,
        SixMonths,
        OneYear,
        Test
    }

    // Withdrawal fee in basis points
    uint256 public withdrawalFee = 100_000; // 1% fee on withdrawal or 100_000/10_000_000
    uint256 public withdrawalFeeDivisor = 10_000_000; // 10_000_000 basis points

    // Founder's reward boost in basis points
    uint256 public foundersRewardBoost = 11_000_000; // 10% boost (=110%) on rewards or 1_000_000/10_000_000
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
    // uint256 public compoundFreq = 60 * 60 * 24; // 24 hours // PROD
    uint256 public compoundFreq = 60 * 60; // 1 hour
    // uint256 public compoundFreq = 60; // 1 minute // gives bugs when unstaking

    // Mapping of address to Staker info
    //mapping(address => Staker) internal stakers;
    mapping(address => uint) name;
    mapping(address => uint[]) public userDepositsIds;
    mapping(uint => Staker) public userDeposits;

    // Staked tokens minimum timelock
    //uint256 public timelock = 60 * 60 * 24 * 1; // 1 days
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
    event WithdrawAll(address indexed staker, uint256 amount);
    event Compound(address indexed staker, uint256 amount);
    event Stake(uint indexed id, address indexed staker, uint256 amount);
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

    // modifier timelocked(uint _id) {
    //     require(block.timestamp >= stakers[msg.sender].timelock, "Timelock not passed");
    //     _;
    // }

    // If address has no Staker struct, initiate one. If address already was a stake,
    // calculate the rewards and add them to unclaimedRewards, reset the last time of
    // deposit and then add _amount to the already deposited amount.
    // Transfers the amount staked.
    function deposit(uint256 _amount, uint8 _timelock) public returns (uint) {
        require(_amount >= minStake, "Amount smaller than minimimum deposit");
        require(konduxERC20.balanceOf(msg.sender) >= _amount, "Can't stake more than you own");
        require(konduxERC20.allowance(msg.sender, address(this)) >= _amount, "Allowance not set");
        require(_timelock >= 0 && _timelock <= 4, "Invalid timelock"); // PROD: 3
        // require(stakers[msg.sender].timelockCategory <= _timelock, "Can't decrease timelock category");

        console.log(konduxERC20.balanceOf(msg.sender)); 
        console.log(_amount);
        console.log(konduxERC20.allowance(msg.sender, address(this))); 

        uint _id = _depositIds.current();

        userDeposits[_id] = Staker({
            staker: msg.sender,
            deposited: _amount,
            unclaimedRewards: 0,
            timelock: 0,
            timelockCategory: _timelock,
            timeOfLastUpdate: block.timestamp,
            lastDepositTime: block.timestamp,
            redeemed: 0
        });             
        
        if (_timelock == uint8(LockingTimes.OneMonth)) {
            userDeposits[_id].timelock = block.timestamp + 30 days; // 1 month
        } else if (_timelock == uint8(LockingTimes.ThreeMonths)) {
            userDeposits[_id].timelock = block.timestamp + 90 days; // 3 months
        } else if (_timelock == uint8(LockingTimes.SixMonths)) {
            userDeposits[_id].timelock = block.timestamp + 180 days; // 6 months
        } else if (_timelock == uint8(LockingTimes.OneYear)) {
            userDeposits[_id].timelock = block.timestamp + 365 days; // 1 year 
        } else if (_timelock == uint8(LockingTimes.Test)) {
            userDeposits[_id].timelock = block.timestamp + 2 minutes; // 2 minutes // TEST
        }

        userDepositsIds[msg.sender].push(_id);         

        konduxERC20.transferFrom(msg.sender, authority.vault(), _amount);
        helixERC20.mint(msg.sender, _amount);
        
        _depositIds.increment(); 

        emit Stake(_id, msg.sender, _amount);

        return _id;
    }

    // Compound the rewards and reset the last time of update for Deposit info
    function stakeRewards(uint _depositId) public {
        require(msg.sender == userDeposits[_depositId].staker, "You are not the owner of this deposit");
        require(compoundRewardsTimer(_depositId) == 0, "Tried to compound rewards too soon"); // incluir depositId

        uint256 rewards = calculateRewards(msg.sender, _depositId) + userDeposits[_depositId].unclaimedRewards; 
        userDeposits[_depositId].unclaimedRewards = 0; 
        userDeposits[_depositId].deposited += rewards;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp; 

        helixERC20.mint(msg.sender, rewards);

        emit Compound(msg.sender, rewards);
    }

    // Transfer rewards to msg.sender
    function claimRewards(uint _depositId) public {
        require(msg.sender == userDeposits[_depositId].staker, "You are not the owner of this deposit");
        require(block.timestamp >= userDeposits[_depositId].timelock, "Timelock not passed");
        // console.log("Claiming rewards");
        // console.log("staking contract address", address(this));

        uint256 rewards = calculateRewards(msg.sender, _depositId) + userDeposits[_depositId].unclaimedRewards; 
        // console.log("rewards: %s", rewards);
        // console.log("pre-claiming balance vault: %s", konduxERC20.balanceOf(authority.vault()));
        // console.log("ERC20 address: %s", address(konduxERC20));
        require(rewards > 0, "You have no rewards");
        userDeposits[_depositId].unclaimedRewards = 0;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;
        helixERC20.burn(msg.sender, rewards);
        konduxERC20.transferFrom(authority.vault(), msg.sender, rewards);
        // console.logString("Rewards claimed");
        // console.log(konduxERC20.balanceOf(authority.vault()));
        emit Reward(msg.sender, rewards);
    }

    // Withdraw specified amount of staked tokens
    function withdraw(uint256 _amount, uint _depositId) public {
        require(msg.sender == userDeposits[_depositId].staker, "You are not the owner of this deposit");
        require(block.timestamp >= userDeposits[_depositId].timelock, "Timelock not passed");
        require(userDeposits[_depositId].deposited >= _amount, "Can't withdraw more than you have");
        require(_amount <= helixERC20.balanceOf(msg.sender), "Can't withdraw more tokens than the collateral you have");
        console.log("Withdrawing");
        console.log("Amount to withdraw: %s", _amount);
        console.log("Deposit ID: %s", _depositId);
        console.log("Staker: %s", userDeposits[_depositId].staker);
        console.log("Staker address: %s", msg.sender);
        console.log("Staker balance: %s", helixERC20.balanceOf(msg.sender)); 
        uint256 _rewards = calculateRewards(msg.sender, _depositId);
        userDeposits[_depositId].deposited -= _amount;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;
        userDeposits[_depositId].unclaimedRewards = _rewards;
        console.log("Rewards: %s", _rewards);
        console.log("withdrawalFee: %s", withdrawalFee);
        console.log("withdrawalFeeDivisor: %s", withdrawalFeeDivisor);
        uint256 _liquid = (_amount * (withdrawalFeeDivisor - withdrawalFee)) / withdrawalFeeDivisor;
        console.log("Liquid: %s", _liquid);
        helixERC20.burn(msg.sender, _amount);
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);
        emit Withdraw(msg.sender, _liquid);
    }

    // Withdraw all stake and rewards and mints them to the msg.sender
    function withdrawAll() public { // fazer depois q tiver view q pega todos os depositos do usuario
        console.log("Withdrawing all");
        uint[] memory _userDepositIds = getDepositIds(msg.sender); 
        uint _liquid = 0;
        uint _rewards = 0;
        uint _deposit = 0;
        for (uint i = 0; i < _userDepositIds.length; i++) {
            console.log("Deposit ID: %s", _userDepositIds[i]);
            require(block.timestamp >= userDeposits[_userDepositIds[i]].timelock, "Timelock not passed");
            console.log("calculated rewards: %s", calculateRewards(msg.sender, _userDepositIds[i]));
            console.log("unclaimed rewards: %s", userDeposits[_userDepositIds[i]].unclaimedRewards);
            _rewards = _rewards + calculateRewards(msg.sender, _userDepositIds[i]) + userDeposits[_userDepositIds[i]].unclaimedRewards;
            _deposit = _deposit + userDeposits[_userDepositIds[i]].deposited;
            userDeposits[_userDepositIds[i]].deposited = 0;
            userDeposits[_userDepositIds[i]].timeOfLastUpdate = 0;
            console.log("Rewards: %s", _rewards);
            
         //   helixERC20.burn(msg.sender, _amount);
           // konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);
           // emit Withdraw(msg.sender, _liquid);
        }

        helixERC20.mint(msg.sender, _rewards);

        uint _amount = _rewards + _deposit; 
        console.log("Amount: %s", _amount); 
        console.log("withdrawalFee: %s", withdrawalFee);
        console.log("withdrawalFeeDivisor: %s", withdrawalFeeDivisor);
        _liquid = (_amount * (withdrawalFeeDivisor - withdrawalFee)) / withdrawalFeeDivisor;
        console.log("****** Liquid: %s", _liquid);
        require(_amount <= helixERC20.balanceOf(msg.sender), "Can't withdraw more tokens than the collateral you have");
        helixERC20.burn(msg.sender, _amount);
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);
        emit WithdrawAll(msg.sender, _liquid);
    }

    // Function useful for fron-end that returns user stake and rewards by address
    function getDepositInfo(address _staker, uint _depositId) public view returns (uint256 _stake, uint256 _rewards) {
        _stake = userDeposits[_depositId].deposited;  
        _rewards = calculateRewards(_staker, _depositId) + userDeposits[_depositId].unclaimedRewards;
        return (_stake, _rewards); 
    }

    // Utility function that returns the timer for restaking rewards
    function compoundRewardsTimer(uint _depositId) public view returns (uint256 _timer) {
        if (userDeposits[_depositId].timeOfLastUpdate + compoundFreq <= block.timestamp) {
            return 0;
        } else {
            return (userDeposits[_depositId].timeOfLastUpdate + compoundFreq) - block.timestamp;
        } 
    }

    // Calculate the rewards since the last update on Deposit info
    function calculateRewards(address _staker, uint _depositId) public view returns (uint256 rewards) {
        console.log("Calculating rewards");
        console.log("stakers[_staker].timeOfLastUpdate: %s", userDeposits[_depositId].timeOfLastUpdate);
        console.log("block.timestamp: %s", block.timestamp);
        console.log("stakers[_staker].deposited: %s", userDeposits[_depositId].deposited);
        console.log("rewardsPerHour: %s", rewardsPerHour);
        console.log("((((block.timestamp - userDeposits[_depositId].timeOfLastUpdate) * userDeposits[_depositId].deposited) * rewardsPerHour) / 3600) / 10_000_000: %s", ((((block.timestamp - userDeposits[_depositId].timeOfLastUpdate) * userDeposits[_depositId].deposited) * rewardsPerHour) / 3600) / 10_000_000);

        uint256 _reward = (((((block.timestamp - userDeposits[_depositId].timeOfLastUpdate) * 
            userDeposits[_depositId].deposited) * rewardsPerHour) / 3600) / 10_000_000); // blocks * staked * rewards/hour / 1h / 10^7

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
            
            //give 1% more for each kNFT owned using kNFTRewardBoost
            _reward = (_reward * (kNFTRewardBoostDivisor + (_kNFTBalance * kNFTRewardBoost))) / kNFTRewardBoostDivisor;

            console.log("reward after kNFT: %s", _reward);
        }

        // add 0% if reward category is 0; add 1% if reward category is 1; add 3% if reward category is 2; add 9% if reward category is 3;
        if (userDeposits[_depositId].timelockCategory == 1) { 
            _reward = (_reward * 10100) / 10000;
        } else if (userDeposits[_depositId].timelockCategory == 2) {
            _reward = (_reward * 10300) / 10000;
        } else if (userDeposits[_depositId].timelockCategory == 3) { 
            _reward = (_reward * 10900) / 10000; 
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
    function getTimeOfLastUpdate(uint _depositId) public view returns (uint256 _timeOfLastUpdate) {
        return userDeposits[_depositId].timeOfLastUpdate;
    }

    // Get staker's deposited amount
    function getStakedAmount(uint _depositId) public view returns (uint256 _deposited) {
        return userDeposits[_depositId].deposited;
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

    function getTimelockCategory(uint _depositId) public view returns (uint8 _timelockCategory) {
        return userDeposits[_depositId].timelockCategory;
    }

    function getTimelock(uint _depositId) public view returns (uint256 _timelock) {
        return userDeposits[_depositId].timelock;
    }

    function getDepositIds(address _user) public view returns (uint256[] memory) {
        return userDepositsIds[_user];
    }

    function getWithdrawalFeeDivisor() public view returns (uint256 _withdrawalFeeDivisor) {
        return withdrawalFeeDivisor;
    }

    function getWithdrawalFee() public view returns (uint256 _withdrawalFee) {
        return withdrawalFee;
    }


}