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
    mapping(address => uint) public name;
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
    mapping (address => uint256) public totalStaked; // token => amount
    mapping (address => mapping (address => uint256)) userTotalStakedByCoin; // token => user => amount


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
            require(_konduxERC721Founders != address(0), "Kondux ERC721 Founders address is not set");
            require(_konduxERC721kNFT != address(0), "Kondux ERC721 kNFT address is not set");
            require(_helixERC20 != address(0), "Helix ERC20 address is not set");           
            
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
            setkNFTRewardBoost(500_000, _konduxERC20); // 5% boost on rewards or 500_000/10_000_000 
            setMinStake(10_000_000, _konduxERC20); // 10,000,000 wei
            setRewardsPerHour(285, _konduxERC20); // 0.00285%/h or 25% APR 285/10_000    = 0.00285           
            setCompoundFreq(60 * 60 * 24, _konduxERC20); // 24 hours 
            setRatio(10_000, _konduxERC20); // 10_000:1 ratio
            _setAuthorizedERC20(_konduxERC20, true);
    }

    /**
     * @dev This function allows a user to deposit a specified amount of an authorized token with a selected timelock period.
     *      The function checks the user's token balance, allowance, and the timelock value before proceeding.
     *      It then creates a new deposit record, sets the timelock based on the selected category, and updates the user's
     *      deposit list and total staked amount. The specified amount of tokens is transferred from the user to the vault,
     *      and an equivalent amount of reward tokens is minted for the user.
     * @param _amount The amount of tokens to deposit.
     * @param _timelock The timelock category, represented as an integer (0-4).
     * @param _token The address of the token contract.
     * @return _id The deposit ID assigned to this deposit.
     */
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

        _addTotalStakedAmount(_amount, _token, msg.sender); 

        konduxERC20.transferFrom(msg.sender, authority.vault(), _amount);
        helixERC20.mint(msg.sender, _amount * ratioERC20[_token]);
        
        _depositIds.increment(); 

        emit Stake(_id, msg.sender, _token, _amount);

        return _id;
    }

    /**
     * @dev This function allows the owner of a deposit to stake their earned rewards.
     *      It verifies that the caller is the deposit owner and that the compounding is not happening too soon.
     *      The function calculates the rewards, resets the unclaimed rewards to zero, and updates the deposit record.
     *      The total staked amount is updated, and an equivalent amount of reward tokens is minted for the user.
     * @param _depositId The ID of the deposit whose rewards are to be staked.
     */
    function stakeRewards(uint _depositId) public {
        require(msg.sender == userDeposits[_depositId].staker, "You are not the owner of this deposit");
        require(compoundRewardsTimer(_depositId) == 0, "Tried to compound rewards too soon"); // incluir depositId

        uint256 rewards = calculateRewards(msg.sender, _depositId) + userDeposits[_depositId].unclaimedRewards; 
        userDeposits[_depositId].unclaimedRewards = 0; 
        userDeposits[_depositId].deposited += rewards;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;

        _addTotalStakedAmount(rewards, userDeposits[_depositId].token, userDeposits[_depositId].staker);

        helixERC20.mint(msg.sender, rewards * ratioERC20[userDeposits[_depositId].token]);

        emit Compound(msg.sender, rewards);
    }

    /**
     * @dev This function allows the owner of a deposit to claim their earned rewards.
     *      It verifies that the caller is the deposit owner and that the timelock has passed.
     *      The function calculates the rewards, resets the unclaimed rewards to zero, and updates the deposit record.
     *      The reward tokens are burned, and the earned rewards are transferred to the user from the vault.
     *      The function emits a Reward event upon successful execution.
     * @param _depositId The ID of the deposit whose rewards are to be claimed.
     */
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
        helixERC20.burn(msg.sender, rewards * ratioERC20[userDeposits[_depositId].token]);
        IERC20 konduxERC20 = IERC20(userDeposits[_depositId].token);
        konduxERC20.transferFrom(authority.vault(), msg.sender, rewards / ratioERC20[userDeposits[_depositId].token]);
        // console.logString("Rewards claimed");
        // console.log(konduxERC20.balanceOf(authority.vault()));
        emit Reward(msg.sender, rewards);
    }

    /**
     * @dev This function allows the owner of a deposit to withdraw a specified amount of their deposited tokens.
     *      It verifies that the timelock has passed, the caller is the deposit owner, and the withdrawal amount
     *      is within the available limits. The function calculates the rewards, updates the deposit record, and
     *      transfers the liquid amount to the user after applying the withdrawal fee. The collateral tokens are burned.
     *      The function emits a Withdraw event upon successful execution.
     * @param _amount The amount of tokens to withdraw.
     * @param _depositId The ID of the deposit from which to withdraw the tokens.
     */
    function withdraw(uint256 _amount, uint _depositId) public {
        require(block.timestamp >= userDeposits[_depositId].timelock, "Timelock not passed");
        require(msg.sender == userDeposits[_depositId].staker, "You are not the owner of this deposit");
        require(userDeposits[_depositId].deposited >= _amount, "Can't withdraw more than you have");
        require(_amount <= helixERC20.balanceOf(msg.sender), "Can't withdraw more tokens than the collateral you have");

        uint256 _rewards = calculateRewards(msg.sender, _depositId);
        userDeposits[_depositId].deposited -= _amount;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;
        userDeposits[_depositId].unclaimedRewards += _rewards;

        uint256 _liquid = (_amount * (withdrawalFeeDivisorERC20[userDeposits[_depositId].token] - withdrawalFeeERC20[userDeposits[_depositId].token])) / withdrawalFeeDivisorERC20[userDeposits[_depositId].token];
        
        IERC20 konduxERC20 = IERC20(userDeposits[_depositId].token);

        require(konduxERC20.allowance(authority.vault(), address(this)) >= _liquid, "Treasury Contract need to approve Staking Contract to withdraw your tokens -- please call an Admin");
        
        _subtractStakedAmount(_amount, userDeposits[_depositId].token, userDeposits[_depositId].staker);

        helixERC20.burn(msg.sender, _amount * ratioERC20[userDeposits[_depositId].token]); 
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);
        emit Withdraw(msg.sender, _liquid);
    }

    /**
     * @dev This function allows the owner of a deposit to withdraw a specified amount of their deposited tokens
     *      and claim their earned rewards in a single transaction. It calls the withdraw and claimRewards functions.
     * @param _amount The amount of tokens to withdraw.
     * @param _depositId The ID of the deposit from which to withdraw the tokens and claim the rewards.
     */
    function withdrawAndClaim(uint256 _amount, uint _depositId) public {
        withdraw(_amount, _depositId);
        claimRewards(_depositId);
    }

    /**
     * @dev This function retrieves the deposit information for a given deposit ID. It returns the staked amount
     *      and the earned rewards (including unclaimed rewards) for the specified deposit.
     * @param _depositId The ID of the deposit for which to retrieve the information.
     * @return _stake The staked amount for the specified deposit.
     * @return _rewards The earned rewards (including unclaimed rewards) for the specified deposit.
     */
    function getDepositInfo(uint _depositId) public view returns (uint256 _stake, uint256 _rewards) {
        _stake = userDeposits[_depositId].deposited;  
        _rewards = calculateRewards(msg.sender, _depositId) + userDeposits[_depositId].unclaimedRewards;
        return (_stake, _rewards); 
    }

    /**
     * @dev This function returns the timer for restaking rewards for a given deposit ID. It calculates the remaining
     *      time until the next allowed compounding action based on the compound frequency for the deposited token.
     *      If the timer has already passed, it returns 0.
     * @param _depositId The ID of the deposit for which to retrieve the timer.
     * @return _timer The remaining time (in seconds) until the next allowed compounding action for the specified deposit.
     */
    function compoundRewardsTimer(uint _depositId) public view returns (uint256 _timer) {
        if (userDeposits[_depositId].timeOfLastUpdate + compoundFreqERC20[userDeposits[_depositId].token] <= block.timestamp) {
            return 0;
        } else {
            return (userDeposits[_depositId].timeOfLastUpdate + compoundFreqERC20[userDeposits[_depositId].token]) - block.timestamp; 
        } 
    }

    /**
     * @dev This function calculates the rewards for a specified staker and deposit ID. The rewards calculation
     *      considers the deposit's elapsed time, staked amount, rewards per hour, and any applicable boosts.
     *      Boosts include founders reward boost, kNFT reward boost, and timelock category reward boost.
     *      If the provided staker is not the owner of the deposit, the function returns 0.
     * @param _staker The address of the staker for which to calculate the rewards.
     * @param _depositId The ID of the deposit for which to calculate the rewards.
     * @return rewards The calculated rewards for the specified staker and deposit ID.
     */
    function calculateRewards(address _staker, uint _depositId) public view returns (uint256 rewards) {
        //check if _staker has _depositId, if not, return 0;
        if (userDeposits[_depositId].staker != _staker) {
            return 0;
        }

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
            
            //give 5% more for each kNFT owned using kNFTRewardBoost
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
    /**
     * @dev This internal function adds the given amount to the total staked amount for a specified token
     *      and increases the staked amount for the user by the same amount.
     * @param _amount The amount to add to the total staked amount and user's staked amount.
     * @param _token The address of the token for which to update the staked amount.
     * @param _user The address of the user whose staked amount should be increased.
     */
    function _addTotalStakedAmount(uint256 _amount, address _token, address _user) internal {
        totalStaked[_token] += _amount;
        userTotalStakedByCoin[_token][_user] += _amount;
    }

    /**
     * @dev This internal function subtracts the given amount from the total staked amount for a specified token
     *      and decreases the staked amount for the user by the same amount.
     * @param _amount The amount to subtract from the total staked amount and user's staked amount.
     * @param _token The address of the token for which to update the staked amount.
     * @param _user The address of the user whose staked amount should be decreased.
     */
    function _subtractStakedAmount(uint256 _amount,  address _token, address _user) internal {
        // do a underflow check
        require(totalStaked[_token] >= _amount, "Staking: Not enough staked (Contract)");
        require(userTotalStakedByCoin[_token][_user] >= _amount, "Staking: Not enough staked (User)");
        totalStaked[_token] -= _amount;
        userTotalStakedByCoin[_token][_user] -= _amount;
    }
    
    /**
     * @dev This function sets the rewards per hour for a specified token.
     * @param _rewardsPerHour The rewards per hour value to be set, as x / 10,000,000. (Example: 100.000 = 1%)
     * @param _tokenId The address of the token for which to set the rewards per hour.
     */
    function setRewards(uint256 _rewardsPerHour, address _tokenId) public onlyGovernor {
        rewardsPerHourERC20[_tokenId] = _rewardsPerHour; 
        emit NewRewardsPerHour(_rewardsPerHour, _tokenId);
    }

    /**
     * @dev This function sets the minimum staking amount for a specified token.
     * @param _minStake The minimum staking amount to be set, in wei.
     * @param _tokenId The address of the token for which to set the minimum staking amount.
     */
    function setMinStake(uint256 _minStake, address _tokenId) public onlyGovernor {
        minStakeERC20[_tokenId] = _minStake;
        emit NewMinStake(_minStake, _tokenId);
    }

    /**
     * @dev This function sets the ratio for a specified ERC20 token.
     * @param _ratio The ratio value to be set.
     * @param _tokenId The address of the token for which to set the ratio.
     */
    function setRatio(uint256 _ratio, address _tokenId) public onlyGovernor {
        ratioERC20[_tokenId] = _ratio;
        emit NewRatio(_ratio, _tokenId);
    }

    /**
     * @dev This function sets the address of the Helix ERC20 contract.
     * @param _helix The address of the Helix ERC20 contract.
     */
    function setHelixERC20(address _helix) public onlyGovernor {
        require(_helix != address(0), "Helix address cannot be 0x0");
        helixERC20 = IHelix(_helix);
        emit NewHelixERC20(_helix);
    }

    /**
     * @dev This function sets the address of the konduxERC721Founders contract.
     * @param _konduxERC721Founders The address of the konduxERC721Founders contract.
     */
    function setKonduxERC721Founders(address _konduxERC721Founders) public onlyGovernor {
        require(_konduxERC721Founders != address(0), "Founders address cannot be 0x0");
        konduxERC721Founders = IERC721(_konduxERC721Founders);
        emit NewKonduxERC721Founders(_konduxERC721Founders);
    }

    /**
     * @dev This function sets the address of the konduxERC721kNFT contract.
     * @param _konduxERC721kNFT The address of the konduxERC721kNFT contract.
     */
    function setKonduxERC721kNFT(address _konduxERC721kNFT) public onlyGovernor {
        require(_konduxERC721kNFT != address(0), "kNFT address cannot be 0x0");
        konduxERC721kNFT = IERC721(_konduxERC721kNFT);
        emit NewKonduxERC721kNFT(_konduxERC721kNFT);
    }

    /**
     * @dev This function sets the address of the Treasury contract.
     * @param _treasury The address of the Treasury contract.
     */
    function setTreasury(address _treasury) public onlyGovernor {
        require(_treasury != address(0), "Treasury address cannot be 0x0");
        treasury = ITreasury(_treasury);
        emit NewTreasury(_treasury);
    }

    /**
     * @dev This function sets the withdrawal fee for a specified token.
     * @param _withdrawalFee The withdrawal fee value to be set.
     * @param _tokenId The address of the token for which to set the withdrawal fee.
     */
    function setWithdrawalFee(uint256 _withdrawalFee, address _tokenId) public onlyGovernor {
        require(_withdrawalFee <= withdrawalFeeDivisorERC20[_tokenId], "Withdrawal fee cannot be more than 100%");
        withdrawalFeeERC20[_tokenId] = _withdrawalFee;
        emit NewWithdrawalFee(_withdrawalFee, _tokenId);
    }

    /**
     * @dev This function sets the withdrawal fee divisor for a specified token.
     * @param _withdrawalFeeDivisor The withdrawal fee divisor value to be set.
     * @param _tokenId The address of the token for which to set the withdrawal fee divisor.
     */
    function setWithdrawalFeeDivisor(uint256 _withdrawalFeeDivisor, address _tokenId) public onlyGovernor {
        withdrawalFeeDivisorERC20[_tokenId] = _withdrawalFeeDivisor;
        emit NewWithdrawalFeeDivisor(_withdrawalFeeDivisor, _tokenId);
    }

    /**
     * @dev This function sets the founders reward boost for a specified token.
     * @param _foundersRewardBoost The founders reward boost value to be set.
     * @param _tokenId The address of the token for which to set the founders reward boost.
     */
    function setFoundersRewardBoost(uint256 _foundersRewardBoost, address _tokenId) public onlyGovernor {
        foundersRewardBoostERC20[_tokenId] = _foundersRewardBoost;
        emit NewFoundersRewardBoost(_foundersRewardBoost, _tokenId);
    }

    /**
     * @dev This function sets the founders reward boost divisor for a specified token.
     * @param _foundersRewardBoostDivisor The founders reward boost divisor value to be set.
     * @param _tokenId The address of the token for which to set the founders reward boost divisor.
     */
    function setFoundersRewardBoostDivisor(uint256 _foundersRewardBoostDivisor, address _tokenId) public onlyGovernor {
        foundersRewardBoostDivisorERC20[_tokenId] = _foundersRewardBoostDivisor; 
        emit NewFoundersRewardBoostDivisor(_foundersRewardBoostDivisor, _tokenId);
    }

    /**
     * @dev This function sets the kNFT reward boost for a specified token.
     * @param _kNFTRewardBoost The kNFT reward boost value to be set.
     * @param _tokenId The address of the token for which to set the kNFT reward boost.
     */
    function setkNFTRewardBoost(uint256 _kNFTRewardBoost, address _tokenId) public onlyGovernor {
        kNFTRewardBoostERC20[_tokenId] = _kNFTRewardBoost;
        emit NewKNFTRewardBoost(_kNFTRewardBoost, _tokenId); 
    }

    /**
     * @dev This function sets the kNFT reward boost divisor for a specified token.
     * @param _kNFTRewardBoostDivisor The kNFT reward boost divisor value to be set.
     * @param _tokenId The address of the token for which to set the kNFT reward boost divisor.
     */
    function setkNFTRewardBoostDivisor(uint256 _kNFTRewardBoostDivisor, address _tokenId) public onlyGovernor {
        kNFTRewardBoostDivisorERC20[_tokenId] = _kNFTRewardBoostDivisor;
        emit NewKNFTRewardBoostDivisor(_kNFTRewardBoostDivisor, _tokenId);  
    }

    /**
     * @dev This function sets the rewards per hour for a specified token.
     * @param _rewardsPerHour The rewards per hour value to be set.
     * @param _tokenId The address of the token for which to set the rewards per hour.
    */
    function setRewardsPerHour(uint256 _rewardsPerHour, address _tokenId) public onlyGovernor {
        rewardsPerHourERC20[_tokenId] = _rewardsPerHour;
        emit NewRewardsPerHour(_rewardsPerHour, _tokenId);
    }

    /**
    * @dev This function sets the compound frequency for a specified token.
    * @param _compoundFreq The compound frequency value to be set.
    * @param _tokenId The address of the token for which to set the compound frequency.
    */
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

    /**
     * @dev This function returns the total amount staked for a specific token.
     * @param _token The address of the token contract.
     * @return _totalStaked The total amount staked for the given token.
     */
    function getTotalStaked(address _token) public view returns (uint256 _totalStaked) {
        return totalStaked[_token];
    }

    /**
     * @dev This function returns the total amount staked by a specific user for a specific token.
     * @param _user The address of the user.
     * @param _token The address of the token contract.
     * @return _totalStaked The total amount staked by the user for the given token.
     */
    function getUserTotalStakedByCoin(address _user, address _token) public view returns (uint256 _totalStaked) {
        return userTotalStakedByCoin[_token][_user];
    }

}