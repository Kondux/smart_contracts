// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

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
        // The address of the token
        address token;
        // The address of the Staker
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
    //uint256 public withdrawalFee = 100_000; // 1% fee on withdrawal or 100_000/10_000_000
    //uint256 public withdrawalFeeDivisor = 10_000_000; // 10_000_000 basis points

    // Founder's reward boost in basis points
    //uint256 public foundersRewardBoost = 11_000_000; // 10% boost (=110%) on rewards or 1_000_000/10_000_000
    //uint256 public foundersRewardBoostDivisor = 10_000_000; // 10_000_000 basis points

    // kNFT reward boost in basis points
    //uint256 public kNFTRewardBoost = 100_000; // 1% boost on rewards or 100_000/10_000_000
    //uint256 public kNFTRewardBoostDivisor = 10_000_000; // 10_000_000 basis points

    // Rewards per hour. A fraction calculated as x/10.000.000 to get the percentage
    // https://www.buybitcoinbank.com/crypto-apy-staking-calculator
    //uint256 public rewardsPerHour = 285; // 0.00285%/h or 25% APR

    // Minimum amount to stake
    //uint256 public minStake = 10_000_000; // 10,000,000 wei

    // Compounding frequency limit in seconds
    // uint256 public compoundFreq = 60 * 60 * 24; // 24 hours // PROD
    //uint256 public compoundFreq = 60 * 60; // 1 hour
    // uint256 public compoundFreq = 60; // 1 minute // gives bugs when unstaking

    // Mapping of address to Staker info
    //mapping(address => Staker) internal stakers;
    mapping(address => uint) name;
    mapping(address => uint[]) public userDepositsIds;
    mapping(uint => Staker) public userDeposits;

    // KonduxERC20 Contract
    //IERC20 public konduxERC20;
    mapping (address => bool) public authorizedERC20;
    mapping (address => uint256) public minStakeERC20;
    mapping (address => uint256) public compoundFreqERC20;
    mapping (address => uint256) public rewardsPerHourERC20;
    mapping (address => uint256) public withdrawalFeeERC20;
    mapping (address => uint256) public withdrawalFeeDivisorERC20;
    mapping (address => uint256) public foundersRewardBoostERC20;
    mapping (address => uint256) public foundersRewardBoostDivisorERC20;
    mapping (address => uint256) public kNFTRewardBoostERC20;
    mapping (address => uint256) public kNFTRewardBoostDivisorERC20;
    mapping (address => uint256) public ratioERC20;


    IHelix public helixERC20;
    IERC721 public konduxERC721Founders;
    IERC721 public konduxERC721kNFT;

    // Treasury Contract
    ITreasury public treasury;

    // Events
    event Withdraw(address indexed staker, uint256 amount);
    event WithdrawAll(address indexed staker, uint256 amount);
    event Compound(address indexed staker, uint256 amount);
    event Stake(uint indexed id, address indexed staker, address token, uint256 amount);
    event Unstake(address indexed staker, uint256 amount); 
    event Reward(address indexed staker, uint256 amount);

    event NewRewardsPerHour(uint256 indexed amount, address indexed token);
    event NewMinStake(uint256 indexed amount, address indexed token);
    event NewCompoundFreq(uint256 indexed amount, address indexed token);
    event NewHelixERC20(address indexed helixERC20);
    event NewKonduxERC721Founders(address indexed konduxERC721Founders);
    event NewKonduxERC721kNFT(address indexed konduxERC721kNFT);
    event NewTreasury(address indexed treasury);
    event NewWithdrawalFee(uint256 indexed amount, address indexed token);
    event NewWithdrawalFeeDivisor(uint256 indexed amount, address indexed token);
    event NewFoundersRewardBoost(uint256 indexed amount, address indexed token);
    event NewFoundersRewardBoostDivisor(uint256 indexed amount, address indexed token);
    event NewKNFTRewardBoost(uint256 indexed amount, address indexed token);
    event NewKNFTRewardBoostDivisor(uint256 indexed amount, address indexed token);
    event NewAuthorizedERC20(address indexed token, bool indexed authorized);
    event NewRatio(uint256 indexed amount, address indexed token);  

    // Constructor function
    constructor(address _authority, address _konduxERC20, address _treasury, address _konduxERC721Founders, address _konduxERC721kNFT, address _helixERC20)
        AccessControlled(IAuthority(_authority)) {        
            require(_konduxERC20 != address(0), "Kondux ERC20 address is not set");
            require(_treasury != address(0), "Treasury address is not set");
            
            konduxERC721Founders = IERC721(_konduxERC721Founders);
            konduxERC721kNFT = IERC721(_konduxERC721kNFT);
            helixERC20 = IHelix(_helixERC20);
            treasury = ITreasury(_treasury);

            // Default Staking Token Setup
            setWithdrawalFeeDivisor(10_000_000, _konduxERC20); // 10_000_000 basis points
            setFoundersRewardBoostDivisor(10_000_000, _konduxERC20); // 10_000_000 basis points
            setkNFTRewardBoostDivisor(10_000_000, _konduxERC20); // 10_000_000 basis points
            setWithdrawalFee(100_000, _konduxERC20); // 1% fee on withdrawal or 100_000/10_000_000
            setFoundersRewardBoost(11_000_000, _konduxERC20); // 10% boost (=110%) on rewards or 1_000_000/10_000_000
            setkNFTRewardBoost(100_000, _konduxERC20); // 1% boost on rewards or 100_000/10_000_000 
            setMinStake(10_000_000, _konduxERC20); // 10,000,000 wei
            setRewardsPerHour(285, _konduxERC20); // 0.00285%/h or 25% APR            
            setCompFreq(60 * 60 * 24, _konduxERC20); // 24 hours
            setRatio(10_000, _konduxERC20); // 10_000:1 ratio
            _setAuthorizedERC20(_konduxERC20, true);
    }

    // If address has no Staker struct, initiate one. If address already was a stake,
    // calculate the rewards and add them to unclaimedRewards, reset the last time of
    // deposit and then add _amount to the already deposited amount.
    // Transfers the amount staked.
    function deposit(uint256 _amount, uint8 _timelock, address _token) public returns (uint) {
        require(authorizedERC20[_token], "Token not authorized");
        require(_amount >= minStakeERC20[_token], "Amount smaller than minimimum deposit"); 
        IERC20 konduxERC20 = IERC20(_token);
        require(konduxERC20.balanceOf(msg.sender) >= _amount, "Can't stake more than you own");
        require(konduxERC20.allowance(msg.sender, address(this)) >= _amount, "Allowance not set");
        require(_timelock >= 0 && _timelock <= 4, "Invalid timelock"); // PROD: 3
        // // require(stakers[msg.sender].timelockCategory <= _timelock, "Can't decrease timelock category");

        // console.log(konduxERC20.balanceOf(msg.sender)); 
        // console.log(_amount);
        // console.log(konduxERC20.allowance(msg.sender, address(this))); 

        uint _id = _depositIds.current();

        userDeposits[_id] = Staker({
            token: _token,
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
        helixERC20.mint(msg.sender, _amount * ratioERC20[_token]);
        
        _depositIds.increment(); 

        emit Stake(_id, msg.sender, _token, _amount * ratioERC20[_token]);

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
        IERC20 konduxERC20 = IERC20(userDeposits[_depositId].token);
        konduxERC20.transferFrom(authority.vault(), msg.sender, rewards / ratioERC20[userDeposits[_depositId].token]);
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
        // console.log("Withdrawing");
        // console.log("Amount to withdraw: %s", _amount);
        // console.log("Deposit ID: %s", _depositId);
        // console.log("Staker: %s", userDeposits[_depositId].staker);
        // console.log("Staker address: %s", msg.sender);
        // console.log("Staker balance: %s", helixERC20.balanceOf(msg.sender)); 
        uint256 _rewards = calculateRewards(msg.sender, _depositId);
        userDeposits[_depositId].deposited -= _amount;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;
        userDeposits[_depositId].unclaimedRewards = _rewards;
        // console.log("Rewards: %s", _rewards);
        // console.log("withdrawalFee: %s", withdrawalFee);
        // console.log("withdrawalFeeDivisor: %s", withdrawalFeeDivisor);
        uint256 _liquid = (_amount * (withdrawalFeeDivisorERC20[userDeposits[_depositId].token] - withdrawalFeeERC20[userDeposits[_depositId].token])) / withdrawalFeeDivisorERC20[userDeposits[_depositId].token];
        console.log("Liquid: %s", _liquid);
        
        IERC20 konduxERC20 = IERC20(userDeposits[_depositId].token);
        console.log("Vault balance: %s", konduxERC20.balanceOf(authority.vault()));
        console.log("Vault address: %s", authority.vault());
        console.log("ERC20 address: %s", address(konduxERC20));
        console.log("ERC20 allowance: %s", konduxERC20.allowance(msg.sender, authority.vault()));
        require(konduxERC20.allowance(authority.vault(), address(this)) >= _liquid, "Treasury Contract need to approve Staking Contract to withdraw your tokens -- please call an Admin"); 

        helixERC20.burn(msg.sender, _amount);
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);
        emit Withdraw(msg.sender, _liquid);
    }

    // Function useful for fron-end that returns user stake and rewards by address
    function getDepositInfo(address _staker, uint _depositId) public view returns (uint256 _stake, uint256 _rewards) {
        _stake = userDeposits[_depositId].deposited;  
        _rewards = calculateRewards(_staker, _depositId) + userDeposits[_depositId].unclaimedRewards;
        return (_stake, _rewards); 
    }

    // Utility function that returns the timer for restaking rewards
    function compoundRewardsTimer(uint _depositId) public view returns (uint256 _timer) {
        if (userDeposits[_depositId].timeOfLastUpdate + compoundFreqERC20[userDeposits[_depositId].token] <= block.timestamp) {
            return 0;
        } else {
            return (userDeposits[_depositId].timeOfLastUpdate + compoundFreqERC20[userDeposits[_depositId].token]) - block.timestamp; 
        } 
    }

    // Calculate the rewards since the last update on Deposit info
    function calculateRewards(address _staker, uint _depositId) public view returns (uint256 rewards) {
        // console.log("Calculating rewards");
        // console.log("stakers[_staker].timeOfLastUpdate: %s", userDeposits[_depositId].timeOfLastUpdate);
        // console.log("block.timestamp: %s", block.timestamp);
        // console.log("stakers[_staker].deposited: %s", userDeposits[_depositId].deposited);
        // console.log("rewardsPerHour: %s", rewardsPerHour);
        // console.log("((((block.timestamp - userDeposits[_depositId].timeOfLastUpdate) * userDeposits[_depositId].deposited) * rewardsPerHour) / 3600) / 10_000_000: %s", ((((block.timestamp - userDeposits[_depositId].timeOfLastUpdate) * userDeposits[_depositId].deposited) * rewardsPerHour) / 3600) / 10_000_000);

        uint256 _reward = (((((block.timestamp - userDeposits[_depositId].timeOfLastUpdate) * 
            userDeposits[_depositId].deposited) * rewardsPerHourERC20[userDeposits[_depositId].token]) / 3600) / 10_000_000); // blocks * staked * rewards/hour / 1h / 10^7

        // console.log("reward: %s", _reward);
        
        if (IERC721(konduxERC721Founders).balanceOf(_staker) > 0) {
            _reward = (_reward * foundersRewardBoostERC20[userDeposits[_depositId].token]) / foundersRewardBoostDivisorERC20[userDeposits[_depositId].token];
            // console.log("reward after founders: %s", _reward);
        }

        if (IERC721(konduxERC721kNFT).balanceOf(_staker) > 0) {
            uint256 _kNFTBalance = IERC721(konduxERC721kNFT).balanceOf(_staker);
            if (_kNFTBalance > 5) {
                _kNFTBalance = 5;
            }
            
            //give 1% more for each kNFT owned using kNFTRewardBoost
            _reward = (_reward * (kNFTRewardBoostDivisorERC20[userDeposits[_depositId].token] + (_kNFTBalance * kNFTRewardBoostERC20[userDeposits[_depositId].token]))) / kNFTRewardBoostDivisorERC20[userDeposits[_depositId].token];

            // console.log("reward after kNFT: %s", _reward);
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
    function setRewards(uint256 _rewardsPerHour, address _tokenId) public onlyGovernor {
        rewardsPerHourERC20[_tokenId] = _rewardsPerHour; 
        emit NewRewardsPerHour(_rewardsPerHour, _tokenId);
    }

    // Set the minimum amount for staking in wei
    function setMinStake(uint256 _minStake, address _tokenId) public onlyGovernor {
        minStakeERC20[_tokenId] = _minStake;
        emit NewMinStake(_minStake, _tokenId);
    }

    // Set the Ratio of a ERC20
    function setRatio(uint256 _ratio, address _tokenId) public onlyGovernor {
        ratioERC20[_tokenId] = _ratio;
        emit NewRatio(_ratio, _tokenId);
    }

    // Set the minimum time that has to pass for a user to be able to restake rewards
    function setCompFreq(uint256 _compoundFreq, address _tokenId) public onlyGovernor {
        compoundFreqERC20[_tokenId] = _compoundFreq;
        emit NewCompoundFreq(_compoundFreq, _tokenId);
    }

    // Set the address of Helix Contract
    function setHelixERC20(address _helix) public onlyGovernor {
        require(_helix != address(0), "Helix address cannot be 0x0");
        helixERC20 = IHelix(_helix);
        emit NewHelixERC20(_helix);
    }

    // Set the address of konduxERC721Founders contract
    function setKonduxERC721Founders(address _konduxERC721Founders) public onlyGovernor {
        require(_konduxERC721Founders != address(0), "Founders address cannot be 0x0");
        konduxERC721Founders = IERC721(_konduxERC721Founders);
        emit NewKonduxERC721Founders(_konduxERC721Founders);
    }

    // Set the address of konduxERC721kNFT contract
    function setKonduxERC721kNFT(address _konduxERC721kNFT) public onlyGovernor {
        require(_konduxERC721kNFT != address(0), "kNFT address cannot be 0x0");
        konduxERC721kNFT = IERC721(_konduxERC721kNFT);
        emit NewKonduxERC721kNFT(_konduxERC721kNFT);
    }

    // Set the address of the Treasury contract
    function setTreasury(address _treasury) public onlyGovernor {
        require(_treasury != address(0), "Treasury address cannot be 0x0");
        treasury = ITreasury(_treasury);
        emit NewTreasury(_treasury);
    }

    // Set the withdrawal fee
    function setWithdrawalFee(uint256 _withdrawalFee, address _tokenId) public onlyGovernor {
        require(_withdrawalFee <= withdrawalFeeDivisorERC20[_tokenId], "Withdrawal fee cannot be more than 100%");
        withdrawalFeeERC20[_tokenId] = _withdrawalFee;
        emit NewWithdrawalFee(_withdrawalFee, _tokenId);
    }

    // Set the withdrawal fee divisor
    function setWithdrawalFeeDivisor(uint256 _withdrawalFeeDivisor, address _tokenId) public onlyGovernor {
        withdrawalFeeDivisorERC20[_tokenId] = _withdrawalFeeDivisor;
        emit NewWithdrawalFeeDivisor(_withdrawalFeeDivisor, _tokenId);
    }

    // Set the founders reward boost
    function setFoundersRewardBoost(uint256 _foundersRewardBoost, address _tokenId) public onlyGovernor {
        foundersRewardBoostERC20[_tokenId] = _foundersRewardBoost;
        emit NewFoundersRewardBoost(_foundersRewardBoost, _tokenId);
    }

    // Set the founders reward boost divisor
    function setFoundersRewardBoostDivisor(uint256 _foundersRewardBoostDivisor, address _tokenId) public onlyGovernor {
        foundersRewardBoostDivisorERC20[_tokenId] = _foundersRewardBoostDivisor; 
        emit NewFoundersRewardBoostDivisor(_foundersRewardBoostDivisor, _tokenId);
    }

    // Set the kNFT reward boost
    function setkNFTRewardBoost(uint256 _kNFTRewardBoost, address _tokenId) public onlyGovernor {
        kNFTRewardBoostERC20[_tokenId] = _kNFTRewardBoost;
        emit NewKNFTRewardBoost(_kNFTRewardBoost, _tokenId); 
    }

    // Set the kNFT reward boost divisor
    function setkNFTRewardBoostDivisor(uint256 _kNFTRewardBoostDivisor, address _tokenId) public onlyGovernor {
        kNFTRewardBoostDivisorERC20[_tokenId] = _kNFTRewardBoostDivisor;
        emit NewKNFTRewardBoostDivisor(_kNFTRewardBoostDivisor, _tokenId);  
    }

    // Set the reward per hour
    function setRewardsPerHour(uint256 _rewardsPerHour, address _tokenId) public onlyGovernor {
        rewardsPerHourERC20[_tokenId] = _rewardsPerHour;
        emit NewRewardsPerHour(_rewardsPerHour, _tokenId);
    }

    // Set the compound frequency
    function setCompoundFreq(uint256 _compoundFreq, address _tokenId) public onlyGovernor {
        compoundFreqERC20[_tokenId] = _compoundFreq;
        emit NewCompoundFreq(_compoundFreq, _tokenId);
    }

    // Set true or false to enable or disable an ERC20 token as staking currency modifiying the map authorizedERC20 
    function _setAuthorizedERC20(address _token, bool _authorized) internal {
        require(_token != address(0), "Token address cannot be 0x0");
        if (_authorized == true) {
            require(rewardsPerHourERC20[_token] > 0, "Rewards per hour must be greater than 0");
            require(compoundFreqERC20[_token] > 0, "Compound frequency must be greater than 0");
            require(withdrawalFeeERC20[_token] > 0, "Withdrawal fee must be greater than 0");
            require(withdrawalFeeDivisorERC20[_token] > 0, "Withdrawal fee divisor must be greater than 0");
            require(foundersRewardBoostERC20[_token] > 0, "Founders reward boost must be greater than 0");
            require(foundersRewardBoostDivisorERC20[_token] > 0, "Founders reward boost divisor must be greater than 0");
            require(kNFTRewardBoostERC20[_token] > 0, "kNFT reward boost must be greater than 0");
            require(kNFTRewardBoostDivisorERC20[_token] > 0, "kNFT reward boost divisor must be greater than 0");
            require(ratioERC20[_token] > 0, "Ratio must be greater than 0");
            require(minStakeERC20[_token] > 0, "Minimum stake must be greater than 0");  
            require(IERC20(_token).totalSupply() > 0, "Token total supply must be greater than 0");
        }
        authorizedERC20[_token] = _authorized;
        emit NewAuthorizedERC20(_token, _authorized);
    }

    function setAuthorizedERC20(address _token, bool _authorized) public onlyGovernor {
        _setAuthorizedERC20(_token, _authorized);
    }

    function addNewStakingToken(address _token, uint256 _rewardsPerHour, uint256 _compoundFreq, uint256 _withdrawalFee, uint256 _withdrawalFeeDivisor, uint256 _foundersRewardBoost, uint256 _foundersRewardBoostDivisor, uint256 _kNFTRewardBoost, uint256 _kNFTRewardBoostDivisor, uint256 _ratio, uint256 _minStake) public onlyGovernor {
        require(_token != address(0), "Token address cannot be 0x0");
        require(_rewardsPerHour > 0, "Rewards per hour must be greater than 0");
        require(_compoundFreq > 0, "Compound frequency must be greater than 0");
        require(_withdrawalFee > 0, "Withdrawal fee must be greater than 0");
        require(_withdrawalFeeDivisor > 0, "Withdrawal fee divisor must be greater than 0");
        require(_foundersRewardBoost > 0, "Founders reward boost must be greater than 0");
        require(_foundersRewardBoostDivisor > 0, "Founders reward boost divisor must be greater than 0");
        require(_kNFTRewardBoost > 0, "kNFT reward boost must be greater than 0");
        require(_kNFTRewardBoostDivisor > 0, "kNFT reward boost divisor must be greater than 0");
        require(_ratio > 0, "Ratio must be greater than 0");
        require(_minStake > 0, "Minimum stake must be greater than 0");
        require(IERC20(_token).totalSupply() > 0, "Token total supply must be greater than 0");
        setWithdrawalFeeDivisor(_withdrawalFeeDivisor, _token);
        setFoundersRewardBoostDivisor(_foundersRewardBoostDivisor, _token); 
        setkNFTRewardBoostDivisor(_kNFTRewardBoostDivisor, _token);
        setFoundersRewardBoost(_foundersRewardBoost, _token);
        setkNFTRewardBoost(_kNFTRewardBoost, _token);
        setRewardsPerHour(_rewardsPerHour, _token); 
        setRatio(_ratio, _token);
        setWithdrawalFee(_withdrawalFee, _token);
        setCompoundFreq(_compoundFreq, _token);
        setMinStake(_minStake, _token);

        _setAuthorizedERC20(_token, true);
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
    function getRewardsPerHour(address _tokenId) public view returns (uint256 _rewardsPerHour) {
        return rewardsPerHourERC20[_tokenId];
    }

    // Get Founder's reward boost
    function getFoundersRewardBoost(address _tokenId) public view returns (uint256 _foundersRewardBoost) {
        return foundersRewardBoostERC20[_tokenId];
    }

    // Get Founder's reward boost divisor
    function getFoundersRewardBoostDenominator(address _tokenId) public view returns (uint256 _foundersRewardBoostDivisor) {
        return foundersRewardBoostDivisorERC20[_tokenId];
    }

    // Get kNFT reward boost
    function getkNFTRewardBoost(address _tokenId) public view returns (uint256 _kNFTRewardBoost) {
        return kNFTRewardBoostERC20[_tokenId];
    }

    // Get kNFT reward boost divisor
    function getKnftRewardBoostDenominator(address _tokenId) public view returns (uint256 _kNFTRewardBoostDivisor) {
        return kNFTRewardBoostDivisorERC20[_tokenId];
    }

    // Get minimum stake
    function getMinStake(address _tokenId) public view returns (uint256 _minStake) {
        return minStakeERC20[_tokenId];
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

    function getWithdrawalFeeDivisor(address _tokenId) public view returns (uint256 _withdrawalFeeDivisor) {
        return withdrawalFeeDivisorERC20[_tokenId];
    }

    function getWithdrawalFee(address _tokenId) public view returns (uint256 _withdrawalFee) {
        return withdrawalFeeERC20[_tokenId]; 
    }


}