// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IHelix.sol";
import "./interfaces/IKondux.sol";
import "./interfaces/IKonduxERC20.sol";
import "./types/AccessControlled.sol";

/**
 * @dev Interface for the Staking V1 contract, allowing us to read user deposit data
 *      and specifically retrieve the old deposit’s APR via getDepositAPR.
 */
interface IStakingV1 {
    function userDepositsIds(address _user) external view returns (uint256[] memory);

    function userDeposits(uint256 _depositId) 
        external 
        view 
        returns (
            address token,
            address staker,
            uint256 deposited,
            uint256 redeemed,
            uint256 timeOfLastUpdate,
            uint256 lastDepositTime,
            uint256 unclaimedRewards,
            uint256 timelock,
            uint8 timelockCategory,
            uint256 ratioERC20
        );

    // New function to fetch the APR that V1 used for this deposit
    function getDepositAPR(uint256 _depositId) external view returns (uint256);

    function compoundFreqERC20(address _token) external view returns (uint256);

    function aprERC20(address _token) external view returns (uint256);

    function calculateBoostPercentage(address _staker, uint256 _stakeId) external view returns (uint256);

    function calculateKNFTBoostPercentage(address _staker, uint256 _stakeId) external view returns (uint256);

 

}

contract Staking is AccessControlled {

    // ---------------------------------
    //  MIGRATION-RELATED VARIABLES
    // ---------------------------------

    /**
     * @dev Reference to Staking V1 (the old contract).
     */
    IStakingV1 public stakingV1;

    /**
     * @dev The first deposit ID used exclusively by Staking V2,
     *      so that any depositId < initialDepositId is recognized as a V1 deposit.
     */
    uint256 public initialDepositId;

    /**
     * @dev Tracks if a V1 deposit ID has been migrated into V2.
     */
    mapping (uint256 => bool) public isV1Migrated;

    // ---------------------------------
    // END MIGRATION-RELATED VARIABLES
    // ---------------------------------

    uint256 private _depositIds;

    /**
     * @dev Struct representing a staker's information in V2.
     */
    struct Staker {
        // The address of the staked token
        address token;
        // The address of the staker
        address staker;
        // The total amount of tokens deposited by the staker
        uint256 deposited;
        // The total amount of tokens redeemed by the staker
        uint256 redeemed;
        // The timestamp of the last update for this staker's deposit
        uint256 timeOfLastUpdate;
        // The timestamp of the staker's last deposit
        uint256 lastDepositTime;
        // The accumulated, but unclaimed rewards
        uint256 unclaimedRewards;
        // The duration of the timelock applied to the staker's deposit
        uint256 timelock;
        // The category of the timelock applied to the staker's deposit
        uint8 timelockCategory;
        // ERC20 Ratio at the time of staking
        uint256 ratioERC20;
        // The APR stored at the time of deposit. We do not auto-update unless user calls stakeRewards().
        uint256 depositApr;
    } 

    enum LockingTimes {        
        OneMonth,      // 0
        ThreeMonths,   // 1
        SixMonths,     // 2
        OneYear        // 3
    }

    // Mapping user => deposit IDs in V2
    mapping(address => uint[]) public userDepositsIds;

    // Mapping deposit ID => Staker struct in V2
    mapping(uint => Staker) public userDeposits;

    // Indicates whether a specific ERC20 token is authorized for staking
    mapping (address => bool) public authorizedERC20;

    // The minimum amount required to stake for a specific ERC20 token
    mapping (address => uint256) public minStakeERC20;

    // The compound frequency for a specific ERC20 token
    mapping (address => uint256) public compoundFreqERC20;

    // The rewards (APR) for a specific ERC20 token (as a percentage, e.g., 25 = 25% APR)
    mapping (address => uint256) public aprERC20;

    // The withdrawal fee for a specific ERC20 token
    mapping (address => uint256) public withdrawalFeeERC20;

    // The founders reward boost for a specific ERC20 token
    mapping (address => uint256) public foundersRewardBoostERC20;

    // The kNFT reward boost for a specific ERC20 token
    mapping (address => uint256) public kNFTRewardBoostERC20;

    // The ratio for a specific ERC20 token
    mapping (address => uint256) public ratioERC20;

    // The decimals of a specific ERC20 token
    mapping (address => uint8) public decimalsERC20;

    // The total amount staked for a specific ERC20 token
    mapping (address => uint256) public totalStaked;

    // The total amount staked by a user for a specific ERC20 token
    mapping (address => mapping (address => uint256)) public userTotalStakedByCoin;

    // The total amount rewarded for a specific ERC20 token
    mapping (address => uint256) public totalRewarded;

    // The total amount rewarded by a user for a specific ERC20 token
    mapping (address => mapping (address => uint256)) public userTotalRewardedByCoin;

    // The total amount paid as a withdrawal fee for a specific ERC20 token
    mapping (address => uint256) public totalWithdrawalFees;

    // The penalty for withdrawing early for a specific ERC20 token
    mapping (address => uint256) public earlyWithdrawalPenalty;

    // The boost for a specific timelock category
    mapping(uint => uint256) public timelockCategoryBoost;

    // The divisor for a specific token
    mapping (address => uint256) public divisorERC20;

    // The allowed dnaVersion for reward boost
    mapping (uint256 => bool) public allowedDnaVersions;

    // Timelock durations
    mapping(uint8 => uint256) public timelockDurations;

    IHelix public helixERC20; 
    IERC721 public konduxERC721Founders; 
    address public konduxERC721kNFT; 
    ITreasury public treasury; 

    // Events
    event Withdraw(address indexed user, uint256 liquidAmount, uint256 fees);
    event WithdrawAll(address indexed staker, uint256 amount);
    event Compound(address indexed staker, uint256 amount);
    event Stake(uint indexed id, address indexed staker, address token, uint256 amount);
    event Unstake(address indexed staker, uint256 amount);
    event Reward(address indexed user, uint256 netRewards, uint256 fees);
    event NewAPR(uint256 indexed amount, address indexed token);
    event NewMinStake(uint256 indexed amount, address indexed token);
    event NewCompoundFreq(uint256 indexed amount, address indexed token);
    event NewHelixERC20(address indexed helixERC20);
    event NewKonduxERC721Founders(address indexed konduxERC721Founders);
    event NewKonduxERC721kNFT(address indexed konduxERC721kNFT);
    event NewTreasury(address indexed treasury);
    event NewWithdrawalFee(uint256 indexed amount, address indexed token);
    event NewFoundersRewardBoost(uint256 indexed amount, address indexed token);
    event NewKNFTRewardBoost(uint256 indexed amount, address indexed token);
    event NewAuthorizedERC20(address indexed token, bool indexed authorized);
    event NewRatio(uint256 indexed amount, address indexed token);
    event NewDivisorERC20(uint256 indexed amount, address indexed token);

    /**
     * @dev Constructor sets default parameters for the "primary" token (Kondux ERC20).
     */
    constructor(
        address _authority,
        address _konduxERC20,
        address _treasury,
        address _konduxERC721Founders,
        address _konduxERC721kNFT,
        address _helixERC20
    ) AccessControlled(IAuthority(_authority)) {
        require(_konduxERC20 != address(0), "Kondux ERC20 address is not set");
        require(_treasury != address(0), "Treasury address is not set");
        require(_konduxERC721Founders != address(0), "Kondux ERC721 Founders address is not set");
        require(_konduxERC721kNFT != address(0), "Kondux ERC721 kNFT address is not set");
        require(_helixERC20 != address(0), "Helix ERC20 address is not set");

        konduxERC721Founders = IERC721(_konduxERC721Founders);
        konduxERC721kNFT = _konduxERC721kNFT;
        helixERC20 = IHelix(_helixERC20);
        treasury = ITreasury(_treasury);

        timelockDurations[0] = 30 days;      
        timelockDurations[1] = 90 days;      
        timelockDurations[2] = 180 days;     
        timelockDurations[3] = 365 days;     

        // Default parameters for your main token
        setDivisorERC20(10_000, _konduxERC20);
        setWithdrawalFee(100, _konduxERC20);        
        setFoundersRewardBoost(1_000, _konduxERC20);
        setkNFTRewardBoost(500, _konduxERC20);
        setMinStake(10_000_000, _konduxERC20);
        setAPR(25, _konduxERC20);
        setCompoundFreq(60 * 60 * 24, _konduxERC20);
        setRatio(10_000, _konduxERC20);
        setEarlyWithdrawalPenalty(_konduxERC20, 10);
        setTimelockCategoryBoost(1, 100);
        setTimelockCategoryBoost(2, 300);
        setTimelockCategoryBoost(3, 900);
        setAllowedDnaVersion(1, true);
        setDecimalsERC20(helixERC20.decimals(), _helixERC20); 
        setDecimalsERC20(IKonduxERC20(_konduxERC20).decimals(), _konduxERC20); 

        // By default, deposit IDs in V2 start at 0. If you have existing V1 deposit IDs,
        // call `setInitialDepositId(...)` to avoid overlap.
        _setAuthorizedERC20(_konduxERC20, true);
    }

    // ---------------------------------------------------
    //               MIGRATION-RELATED
    // ---------------------------------------------------

    /**
     * @dev Set the address of the old Staking V1 contract
     */
    function setStakingV1Contract(address _v1) external onlyGovernor {
        require(_v1 != address(0), "Invalid V1 address");
        stakingV1 = IStakingV1(_v1);
    }

    /**
     * @dev Sets the deposit ID from which V2 will start, ensuring V1 deposit IDs are all < initialDepositId.
     *      If V1’s last deposit ID was 1234, set this to 1235 so we do not overlap.
     */
    function setInitialDepositId(uint256 _initialDepositId) external onlyGovernor {
        require(_depositIds == 0, "V2 deposit IDs already in use");
        initialDepositId = _initialDepositId;
        // from now on, new V2 deposits will start at `_initialDepositId`
        _depositIds = _initialDepositId;
    }

    /**
     * @dev Check if deposit is from V1
     */
    function _isV1Deposit(uint256 depositId) internal view returns (bool) {
        return (depositId < initialDepositId);
    }

    /**
     * @dev Migrate a deposit from V1 to V2 (pull all fields, including old APR).
     *      We store the exact old deposit APR in `depositApr`.
     */
    function _migrateV1Deposit(uint256 _depositId) internal {
        require(!isV1Migrated[_depositId], "Already migrated");

        (
            address token,
            address staker,
            uint256 deposited,
            uint256 redeemed,
            uint256 timeOfLastUpdate,
            uint256 lastDepositTime,
            uint256 unclaimedRewards,
            uint256 timelock,
            uint8 timelockCategory,
            uint256 ratio
        ) = stakingV1.userDeposits(_depositId);

        // Make sure caller is the staker for that deposit
        require(msg.sender == staker, "Caller not deposit owner (V1)");

        // Now fetch its old deposit APR from V1
        uint256 oldDepositApr = stakingV1.getDepositAPR(_depositId);

        // Mark as migrated
        isV1Migrated[_depositId] = true;

        // Create the deposit in V2 under the same depositId
        userDeposits[_depositId] = Staker({
            token: token,
            staker: staker,
            deposited: deposited,
            redeemed: redeemed,
            timeOfLastUpdate: timeOfLastUpdate,
            lastDepositTime: lastDepositTime,
            unclaimedRewards: unclaimedRewards,
            timelock: timelock,
            timelockCategory: timelockCategory,
            ratioERC20: ratio,
            // Use the old deposit APR to preserve user’s original rate
            depositApr: oldDepositApr
        });

        // Add that deposit ID to V2's userDepositsIds
        userDepositsIds[staker].push(_depositId);
    }

    /**
     * @dev Whenever a user calls a function with a depositId from V1, 
     *      we first check if it's already migrated. If not, we do so.
     */
    function _checkAndMigrateV1Deposit(uint256 _depositId) internal {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            _migrateV1Deposit(_depositId);
        }
    }

    // ---------------------------------------------------
    //               V2 FUNCTIONALITY
    // ---------------------------------------------------

    function deposit(uint256 _amount, uint8 _timelock, address _token) public returns (uint) {
        require(_token != address(0), "Token address not set");
        require(authorizedERC20[_token], "Token not authorized");
        require(_amount >= minStakeERC20[_token], "Amount below min stake");
        IERC20 konduxERC20 = IERC20(_token);
        require(konduxERC20.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(konduxERC20.allowance(msg.sender, address(this)) >= _amount, "Allowance not set");
        require(_timelock <= 3, "Invalid timelock");

        // This deposit's new ID from our local counter
        uint _id = _depositIds;

        userDeposits[_id] = Staker({
            token: _token,
            staker: msg.sender,
            deposited: _amount,
            unclaimedRewards: 0,
            timelock: block.timestamp + timelockDurations[_timelock],
            timelockCategory: _timelock,
            timeOfLastUpdate: block.timestamp,
            lastDepositTime: block.timestamp,
            redeemed: 0,
            ratioERC20: ratioERC20[_token],
            // The APR at the moment of deposit
            depositApr: aprERC20[_token]
        });

        userDepositsIds[msg.sender].push(_id);

        _addTotalStakedAmount(_amount, _token, msg.sender);
        konduxERC20.transferFrom(msg.sender, authority.vault(), _amount);

        // Mint Helix collateral
        uint8 originalTokenDecimals = decimalsERC20[_token];
        uint8 helixDecimals = decimalsERC20[address(helixERC20)];
        uint decimalDifference = 0;
        if (helixDecimals > originalTokenDecimals) {
            decimalDifference = helixDecimals - originalTokenDecimals;
        }
        helixERC20.mint(msg.sender, _amount * ratioERC20[_token] * (10 ** decimalDifference));

        // Increment for next deposit
        _depositIds++;

        emit Stake(_id, msg.sender, _token, _amount);
        return _id;
    }

    function stakeRewards(uint _depositId) public {
        // If deposit is from V1, migrate first
        _checkAndMigrateV1Deposit(_depositId);

        require(msg.sender == userDeposits[_depositId].staker, "Not deposit owner");

        uint256 rewards = calculateRewards(msg.sender, _depositId) 
                            + userDeposits[_depositId].unclaimedRewards;
        require(rewards > 0, "No rewards");

        userDeposits[_depositId].unclaimedRewards = 0;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;

        // If global APR changed for that token, store new for future
        address tokenForDeposit = userDeposits[_depositId].token;
        uint256 currentApr = aprERC20[tokenForDeposit];
        if (currentApr != userDeposits[_depositId].depositApr) {
            userDeposits[_depositId].depositApr = currentApr;
        }

        userDeposits[_depositId].deposited += rewards;
        _addTotalStakedAmount(rewards, tokenForDeposit, userDeposits[_depositId].staker);

        uint8 originalTokenDecimals = decimalsERC20[tokenForDeposit];
        uint8 helixDecimals = decimalsERC20[address(helixERC20)];
        uint decimalDifference = 0;
        if (helixDecimals > originalTokenDecimals) {
            decimalDifference = helixDecimals - originalTokenDecimals;
        }
        helixERC20.mint(msg.sender, rewards * userDeposits[_depositId].ratioERC20 * (10 ** decimalDifference));

        emit Compound(msg.sender, rewards);
    }

    function claimRewards(uint _depositId) public {
        _checkAndMigrateV1Deposit(_depositId);

        require(msg.sender == userDeposits[_depositId].staker, "Not deposit owner");
        require(block.timestamp >= userDeposits[_depositId].timelock, "Timelock not passed");

        uint256 rewards = calculateRewards(msg.sender, _depositId) 
                            + userDeposits[_depositId].unclaimedRewards;
        require(rewards > 0, "No rewards");

        userDeposits[_depositId].unclaimedRewards = 0;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;

        IERC20 konduxERC20 = IERC20(userDeposits[_depositId].token);

        uint256 netRewards = (rewards * (10_000 - withdrawalFeeERC20[userDeposits[_depositId].token])) 
                                / divisorERC20[userDeposits[_depositId].token];
        uint256 fees = rewards - netRewards;

        konduxERC20.transferFrom(authority.vault(), msg.sender, netRewards); 

        _addTotalRewardedAmount(netRewards, userDeposits[_depositId].token, userDeposits[_depositId].staker);
        _addTotalWithdrawalFees(fees, userDeposits[_depositId].token);

        emit Reward(msg.sender, netRewards, fees);
    }

    function withdraw(uint256 _amount, uint _depositId) public {
        _checkAndMigrateV1Deposit(_depositId);

        require(block.timestamp >= userDeposits[_depositId].timelock, "Timelock not passed");
        require(msg.sender == userDeposits[_depositId].staker, "Not deposit owner");
        require(userDeposits[_depositId].deposited >= _amount, "Exceeds deposit");
        require(_amount * userDeposits[_depositId].ratioERC20 <= helixERC20.balanceOf(msg.sender),
                "Not enough collateral");

        uint256 _rewards = calculateRewards(msg.sender, _depositId);

        userDeposits[_depositId].deposited -= _amount;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;
        userDeposits[_depositId].unclaimedRewards += _rewards;

        uint256 _liquid = (_amount * 
                          (divisorERC20[userDeposits[_depositId].token] 
                           - withdrawalFeeERC20[userDeposits[_depositId].token])) 
                          / divisorERC20[userDeposits[_depositId].token];
        uint256 fees = _amount - _liquid;

        IERC20 konduxERC20 = IERC20(userDeposits[_depositId].token);
        require(konduxERC20.allowance(authority.vault(), address(this)) >= _liquid,
                "Treasury must approve withdraw tokens");

        _subtractStakedAmount(_amount, userDeposits[_depositId].token, userDeposits[_depositId].staker);

        uint8 originalTokenDecimals = decimalsERC20[userDeposits[_depositId].token];
        uint8 helixDecimals = decimalsERC20[address(helixERC20)];
        uint decimalDifference = 0;
        if (originalTokenDecimals < helixDecimals) {
            decimalDifference = helixDecimals - originalTokenDecimals;
        }

        helixERC20.burn(msg.sender, _amount * userDeposits[_depositId].ratioERC20 * (10 ** decimalDifference));
        
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);

        _addTotalRewardedAmount(_liquid, userDeposits[_depositId].token, userDeposits[_depositId].staker); 
        _addTotalWithdrawalFees(fees, userDeposits[_depositId].token); 

        emit Withdraw(msg.sender, _liquid, fees);
    }

    function earlyUnstake(uint256 _amount, uint _depositId) public {
        _checkAndMigrateV1Deposit(_depositId);

        require(msg.sender == userDeposits[_depositId].staker, "Not deposit owner");
        require(userDeposits[_depositId].deposited >= _amount, "Exceeds deposit");
        require(_amount * userDeposits[_depositId].ratioERC20 <= helixERC20.balanceOf(msg.sender),
                "Not enough collateral");
        require(block.timestamp < userDeposits[_depositId].timelock, "Timelock passed");

        uint256 timeLeft = userDeposits[_depositId].timelock - block.timestamp;
        uint256 lockDuration = userDeposits[_depositId].timelock - userDeposits[_depositId].lastDepositTime;
        uint256 extraFee = (_amount * earlyWithdrawalPenalty[userDeposits[_depositId].token] * timeLeft) 
                            / (lockDuration * 100);

        if (extraFee > _amount) {
            extraFee = _amount;
        }
        if (extraFee == 0) {
            extraFee = (_amount * 1) / 100;
        }

        uint256 totalFeePercentage = extraFee + withdrawalFeeERC20[userDeposits[_depositId].token];
        uint256 _liquid = (_amount - totalFeePercentage);
        uint256 fees = _amount - _liquid;

        userDeposits[_depositId].deposited -= _amount;
        userDeposits[_depositId].timeOfLastUpdate = block.timestamp;

        IERC20 konduxERC20 = IERC20(userDeposits[_depositId].token);
        require(konduxERC20.allowance(authority.vault(), address(this)) >= _liquid,
                "Treasury must approve withdraw tokens");

        _subtractStakedAmount(_amount, userDeposits[_depositId].token, userDeposits[_depositId].staker);

        uint decimalDifference = 0;
        if (decimalsERC20[userDeposits[_depositId].token] < decimalsERC20[address(helixERC20)]) {
            decimalDifference = decimalsERC20[address(helixERC20)] - decimalsERC20[userDeposits[_depositId].token];
        }

        helixERC20.burn(msg.sender, _amount * userDeposits[_depositId].ratioERC20 * (10 ** decimalDifference));
        
        konduxERC20.transferFrom(authority.vault(), msg.sender, _liquid);

        _addTotalRewardedAmount(_liquid, userDeposits[_depositId].token, userDeposits[_depositId].staker); 
        _addTotalWithdrawalFees(fees, userDeposits[_depositId].token); 

        emit Withdraw(msg.sender, _liquid, fees);
    }

    function withdrawAndClaim(uint256 _amount, uint _depositId) public {
        withdraw(_amount, _depositId);
        claimRewards(_depositId);
    }

    function compoundRewardsTimer(uint _depositId) public view returns (uint256 remainingTime) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            // 1. Read deposit data from V1
            (
                address token,
                /* staker */,
                /* deposited */,
                /* redeemed */,
                uint256 timeOfLastUpdate,
                /* lastDepositTime */,
                /* unclaimedRewards */,
                /* timelock */,
                /* timelockCategory */,
                /* ratioERC20 */
            ) = stakingV1.userDeposits(_depositId);

            // 2. Read the compound frequency from V1’s public mapping
            uint256 freq = stakingV1.compoundFreqERC20(token);

            // 3. Calculate how many seconds remain until next compound
            if (block.timestamp >= timeOfLastUpdate + freq) {
                return 0;
            }
            return (timeOfLastUpdate + freq) - block.timestamp;

        } else {
            // Deposit is already migrated or is originally V2
            uint256 lastUpdateTime = userDeposits[_depositId].timeOfLastUpdate;
            address token = userDeposits[_depositId].token;
            uint256 freq = compoundFreqERC20[token];

            if (block.timestamp >= lastUpdateTime + freq) {
                return 0;
            }
            return (lastUpdateTime + freq) - block.timestamp;
        }
    }



    function calculateRewards(address _staker, uint _depositId) public view returns (uint256 rewards) {
        // -----------------------------------------
        // 1) CHECK IF IT'S A V1 DEPOSIT (UNMIGRATED)
        // -----------------------------------------
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            // We fetch data from V1’s userDeposits(...) 
            (
                address token,
                address staker,
                uint256 deposited,
                /* redeemed */,
                uint256 timeOfLastUpdate,
                /* lastDepositTime */,
                /* unclaimedRewards */,
                /* timelock */,
                /* timelockCategory */,
                /* ratioERC20 */
            ) = stakingV1.userDeposits(_depositId);

            // Ensure the caller is the owner
            if (staker != _staker) {
                return 0;
            }

            // V1 uses a per-token APR in aprERC20
            uint256 _tokenApr = stakingV1.aprERC20(token); 

            // Calculate elapsed time
            uint256 _elapsedTime = block.timestamp - timeOfLastUpdate;

            // The standard reward formula: 
            //   rewardPerSecond = (deposited * APR) / (seconds per year * 100)
            //   totalRewards    = rewardPerSecond * elapsedTime
            //
            // We use 1e18 for scaling to avoid truncation, same as in your V2 logic.
            uint256 _rewardPerSecond = (deposited * _tokenApr * 1e18) / (365 * 24 * 3600 * 100);
            uint256 __reward = (_elapsedTime * _rewardPerSecond) / 1e18;  

            // For demonstration, we do NOT apply any boosts for unmigrated V1 deposits 
            // (since that logic may differ in V1). 
            // If you want to replicate V1’s boost logic, you’d read from V1 or do a fallback.

            return __reward; 
        }

        // -----------------------------
        // 2) IF ALREADY MIGRATED OR V2
        // -----------------------------
        Staker memory deposit_ = userDeposits[_depositId];
        if (deposit_.staker != _staker) {
            return 0;
        }

        // Normal V2 logic:
        uint256 elapsedTime = block.timestamp - deposit_.timeOfLastUpdate;
        uint256 depositedAmount = deposit_.deposited;
        uint256 tokenApr = deposit_.depositApr;

        uint256 rewardPerSecond = (depositedAmount * tokenApr * 1e18) 
                                / (365 * 24 * 3600 * 100);

        uint256 _reward = (elapsedTime * rewardPerSecond) / 1e18;

        // Apply V2’s boosts (Founders NFT, kNFT, timelock).
        uint256 boostPercentage = calculateBoostPercentage(_staker, _depositId);
        _reward = (_reward * boostPercentage) / divisorERC20[deposit_.token];

        return _reward;
    }


    // ---------------------------------
    // Internal bookkeeping
    // ---------------------------------

    function _addTotalRewardedAmount(uint256 _amount, address _token, address _user) internal {
        totalRewarded[_token] += _amount;
        userTotalRewardedByCoin[_token][_user] += _amount;
    }

    function _addTotalStakedAmount(uint256 _amount, address _token, address _user) internal {
        totalStaked[_token] += _amount;
        userTotalStakedByCoin[_token][_user] += _amount;
    }

    function _subtractStakedAmount(uint256 _amount,  address _token, address _user) internal {
        require(totalStaked[_token] >= _amount, "Not enough staked (Contract)");
        require(userTotalStakedByCoin[_token][_user] >= _amount, "Not enough staked (User)");
        totalStaked[_token] -= _amount;
        userTotalStakedByCoin[_token][_user] -= _amount;
    }

    function _addTotalWithdrawalFees(uint256 _amount, address _token) internal {
        totalWithdrawalFees[_token] += _amount;
    }

    // ---------------------------------
    //     GOVERNANCE SETTERS
    // ---------------------------------

    function setAPR(uint256 _apr, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        aprERC20[_tokenId] = _apr; 
        emit NewAPR(_apr, _tokenId);
    }

    function setMinStake(uint256 _minStake, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        minStakeERC20[_tokenId] = _minStake;
        emit NewMinStake(_minStake, _tokenId);
    }

    function setRatio(uint256 _ratio, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        ratioERC20[_tokenId] = _ratio;
        emit NewRatio(_ratio, _tokenId);
    }

    function setHelixERC20(address _helix) public onlyGovernor {
        require(_helix != address(0), "Helix cannot be 0x0");
        helixERC20 = IHelix(_helix);
        emit NewHelixERC20(_helix);
    }

    function setKonduxERC721Founders(address _konduxERC721Founders) public onlyGovernor {
        require(_konduxERC721Founders != address(0), "Founders cannot be 0x0");
        konduxERC721Founders = IERC721(_konduxERC721Founders);
        emit NewKonduxERC721Founders(_konduxERC721Founders);
    }

    function setKonduxERC721kNFT(address _konduxERC721kNFT) public onlyGovernor {
        require(_konduxERC721kNFT != address(0), "kNFT cannot be 0x0");
        konduxERC721kNFT = _konduxERC721kNFT;
        emit NewKonduxERC721kNFT(_konduxERC721kNFT);
    }

    function setTreasury(address _treasury) public onlyGovernor {
        require(_treasury != address(0), "Treasury cannot be 0x0");
        treasury = ITreasury(_treasury);
        emit NewTreasury(_treasury);
    }

    function setWithdrawalFee(uint256 _withdrawalFee, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        require(_withdrawalFee <= divisorERC20[_tokenId], "Fee > 100%");
        withdrawalFeeERC20[_tokenId] = _withdrawalFee;
        emit NewWithdrawalFee(_withdrawalFee, _tokenId); 
    }

    function setFoundersRewardBoost(uint256 _foundersRewardBoost, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        foundersRewardBoostERC20[_tokenId] = _foundersRewardBoost;
        emit NewFoundersRewardBoost(_foundersRewardBoost, _tokenId);
    }

    function setkNFTRewardBoost(uint256 _kNFTRewardBoost, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        kNFTRewardBoostERC20[_tokenId] = _kNFTRewardBoost;
        emit NewKNFTRewardBoost(_kNFTRewardBoost, _tokenId); 
    }

    function setCompoundFreq(uint256 _compoundFreq, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        compoundFreqERC20[_tokenId] = _compoundFreq;
        emit NewCompoundFreq(_compoundFreq, _tokenId);
    }

    function setEarlyWithdrawalPenalty(address _token, uint256 penaltyPercentage) public onlyGovernor {
        require(_token != address(0), "Token not set"); 
        require(penaltyPercentage <= 100, "Penalty must be <= 100%");
        earlyWithdrawalPenalty[_token] = penaltyPercentage;
    }  

    function setTimelockCategoryBoost(uint _category, uint256 _boost) public onlyGovernor {
        timelockCategoryBoost[_category] = _boost;
    }

    function setDivisorERC20(uint256 _divisor, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        divisorERC20[_tokenId] = _divisor;
        emit NewDivisorERC20(_divisor, _tokenId);
    }

    function _setAuthorizedERC20(address _token, bool _authorized) internal {
        require(_token != address(0), "Token cannot be 0x0");
        if (_authorized) {
            require(aprERC20[_token] > 0, "APR=0");
            require(compoundFreqERC20[_token] > 0, "compoundFreq=0");
            require(withdrawalFeeERC20[_token] > 0, "withdrawalFee=0");
            require(foundersRewardBoostERC20[_token] > 0, "foundersRewardBoost=0");
            require(kNFTRewardBoostERC20[_token] > 0, "kNFTRewardBoost=0");
            require(ratioERC20[_token] > 0, "ratio=0");
            require(minStakeERC20[_token] > 0, "minStake=0");
            require(divisorERC20[_token] > 0, "divisor=0");
            require(IERC20(_token).totalSupply() > 0, "No supply");
        }
        authorizedERC20[_token] = _authorized;
        emit NewAuthorizedERC20(_token, _authorized);
    }

    function setAuthorizedERC20(address _token, bool _authorized) public onlyGovernor {
        require(_token != address(0), "Token not set"); 
        _setAuthorizedERC20(_token, _authorized);
    }

    function setAllowedDnaVersion(uint256 _dnaVersion, bool _allowed) public onlyGovernor {
        allowedDnaVersions[_dnaVersion] = _allowed;
    }

    function setDecimalsERC20(uint8 _decimals, address _tokenId) public onlyGovernor {
        require(_tokenId != address(0), "Token not set"); 
        decimalsERC20[_tokenId] = _decimals;
    }

    function addNewStakingToken(
        address _token, 
        uint256 _apr, 
        uint256 _compoundFreq, 
        uint256 _withdrawalFee, 
        uint256 _foundersRewardBoost, 
        uint256 _kNFTRewardBoost, 
        uint256 _ratio, 
        uint256 _minStake
    ) 
        public 
        onlyGovernor 
    {
        require(_token != address(0), "Token=0");
        require(_apr > 0, "APR=0"); 
        require(_compoundFreq > 0, "compoundFreq=0");
        require(_withdrawalFee > 0, "withdrawalFee=0");
        require(_foundersRewardBoost > 0, "foundersRewardBoost=0");
        require(_kNFTRewardBoost > 0, "kNFTRewardBoost=0");
        require(_ratio > 0, "ratio=0");
        require(_minStake > 0, "minStake=0");
        require(IERC20(_token).totalSupply() > 0, "No supply");

        setDivisorERC20(10_000, _token);
        setFoundersRewardBoost(_foundersRewardBoost, _token);
        setkNFTRewardBoost(_kNFTRewardBoost, _token);
        setAPR(_apr, _token); 
        setRatio(_ratio, _token);
        setWithdrawalFee(_withdrawalFee, _token);
        setCompoundFreq(_compoundFreq, _token);
        setMinStake(_minStake, _token);
        setDecimalsERC20(IERC20Metadata(_token).decimals(), _token);

        _setAuthorizedERC20(_token, true); 
    }

    // ---------------------------------
    //          VIEW FUNCTIONS
    // ---------------------------------

    /**
     * @dev Return all deposit IDs for a user, merging V1 + V2.
     *      V1 deposits appear if the user had them. 
     */
    function getDepositIds(address _user) public view returns (uint256[] memory) {
        // V2 IDs
        uint256[] memory v2Ids = userDepositsIds[_user];

        if (address(stakingV1) == address(0)) {
            return v2Ids;
        }

        // V1 IDs
        uint256[] memory v1Ids = stakingV1.userDepositsIds(_user);

        // Merge them
        uint256 totalLen = v2Ids.length + v1Ids.length;
        uint256[] memory allIds = new uint256[](totalLen);
        uint256 i;

        for (; i < v1Ids.length; i++) {
            allIds[i] = v1Ids[i];
        }
        for (uint256 j = 0; j < v2Ids.length; j++) {
            allIds[i + j] = v2Ids[j];
        }
        return allIds;
    }

    function getTimeOfLastUpdate(uint _depositId) public view returns (uint256 _timeOfLastUpdate) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            (
                , 
                ,
                ,
                ,
                uint256 timeOfLastUpdate,
                ,
                ,
                ,
                ,
                
            ) = stakingV1.userDeposits(_depositId);
            return timeOfLastUpdate;
        }
        return userDeposits[_depositId].timeOfLastUpdate;
    }

    function getStakedAmount(uint _depositId) public view returns (uint256 _deposited) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            (
                , 
                ,
                uint256 deposited,
                ,
                ,
                ,
                ,
                ,
                ,
                
            ) = stakingV1.userDeposits(_depositId);
            return deposited;
        }
        return userDeposits[_depositId].deposited;
    }

    function getAPR(address _tokenId) public view returns (uint256 _apr) {
        return aprERC20[_tokenId];
    }

    function getFoundersRewardBoost(address _tokenId) public view returns (uint256 _foundersRewardBoost) {
        return foundersRewardBoostERC20[_tokenId];
    }

    function getkNFTRewardBoost(address _tokenId) public view returns (uint256 _kNFTRewardBoost) {
        return kNFTRewardBoostERC20[_tokenId];
    }

    function getMinStake(address _tokenId) public view returns (uint256 _minStake) {
        return minStakeERC20[_tokenId];
    }

    function getTimelockCategory(uint _depositId) public view returns (uint8 _timelockCategory) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            (
                , 
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint8 category,
                
            ) = stakingV1.userDeposits(_depositId);
            return category;
        }
        return userDeposits[_depositId].timelockCategory;
    }

    function getTimelock(uint _depositId) public view returns (uint256 _timelock) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            (
                , 
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 tl,
                ,
                
            ) = stakingV1.userDeposits(_depositId);
            return tl;
        }
        return userDeposits[_depositId].timelock;
    }

    function getWithdrawalFee(address _tokenId) public view returns (uint256 _withdrawalFee) {
        return withdrawalFeeERC20[_tokenId]; 
    }

    function getTotalStaked(address _token) public view returns (uint256 _totalStaked) {
        return totalStaked[_token];
    }

    function getUserTotalStakedByCoin(address _user, address _token) public view returns (uint256 _totalStaked) {
        return userTotalStakedByCoin[_token][_user];
    }

    function getTotalRewards(address _token) public view returns (uint256 _totalRewards) {
        return totalRewarded[_token];
    }

    function getUserTotalRewardsByCoin(address _user, address _token) public view returns (uint256 _totalRewards) {
        return userTotalRewardedByCoin[_token][_user]; 
    }

    function getTotalWithdrawalFees(address _token) public view returns (uint256 _totalWithdrawalFees) {
        return totalWithdrawalFees[_token];
    }

    function getDepositTimestamp(uint _depositId) public view returns (uint256 _depositTimestamp) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            (
                , 
                ,
                ,
                ,
                ,
                uint256 lastDepositTime,
                ,
                ,
                ,
                
            ) = stakingV1.userDeposits(_depositId);
            return lastDepositTime;
        }
        return userDeposits[_depositId].lastDepositTime; 
    }

    function getEarlyWithdrawalPenalty(address token) public view returns (uint256) {
        return earlyWithdrawalPenalty[token];
    }

    function getTimelockCategoryBoost(uint _category) public view returns (uint256) {
        return timelockCategoryBoost[_category];
    }

    function getDivisorERC20(address _token) public view returns (uint256) {
        return divisorERC20[_token];
    }

    function getAllowedDnaVersion(uint256 _dnaVersion) public view returns (bool) {
        return allowedDnaVersions[_dnaVersion];
    }

    /**
     * @dev For an unmigrated V1 deposit, we show partial data. For a V2 deposit, 
     *      we calculate new rewards plus unclaimed.
     */
    function getDepositInfo(uint _depositId) public view returns (uint256 _stake, uint256 _unclaimedRewards) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            (
                ,
                address staker,
                uint256 deposited,
                ,
                ,
                ,
                uint256 unclaimed,
                ,
                ,
                
            ) = stakingV1.userDeposits(_depositId);

            _stake = deposited;
            // We'll only show unclaimed if the caller is the staker, to mirror V2 logic
            if (staker == msg.sender) {
                _unclaimedRewards = unclaimed;
            } else {
                _unclaimedRewards = 0;
            }
            return (_stake, _unclaimedRewards);
        }
        _stake = userDeposits[_depositId].deposited;  
        _unclaimedRewards = calculateRewards(msg.sender, _depositId) 
                            + userDeposits[_depositId].unclaimedRewards;
        return (_stake, _unclaimedRewards);  
    }

    function getDecimalsERC20(address _token) public view returns (uint8) {
        return decimalsERC20[_token];
    }

    function getRatioERC20(address _token) public view returns (uint256) {
        return ratioERC20[_token];
    }

    function getDepositRatioERC20(uint256 _depositId) public view returns (uint256) {
        if (_isV1Deposit(_depositId) && !isV1Migrated[_depositId]) {
            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 ratio
            ) = stakingV1.userDeposits(_depositId);
            return ratio;
        }
        return userDeposits[_depositId].ratioERC20;
    }   

    function getTop5BonusesAndIds(address _staker, uint256 _stakeId) 
        public 
        view 
        returns (uint256[] memory top5Bonuses, uint256[] memory top5Ids) 
    {
        // If deposit is not migrated from V1, skip logic or replicate
        if (_isV1Deposit(_stakeId) && !isV1Migrated[_stakeId]) {
            return (new uint256[](5), new uint256[](5));
        }

        uint256 kNFTBalance = IERC721(konduxERC721kNFT).balanceOf(_staker);

        top5Bonuses = new uint256[](5);
        top5Ids = new uint256[](5);

        for (uint256 i = 0; i < kNFTBalance; i++) {
            uint256 tokenId = IERC721Enumerable(konduxERC721kNFT).tokenOfOwnerByIndex(_staker, i);

            // If user's kNFT was received after deposit date, skip
            if (IKondux(konduxERC721kNFT).getTransferDate(tokenId) > userDeposits[_stakeId].lastDepositTime) {
                continue;
            }

            int256 dnaVersion = IKondux(konduxERC721kNFT).readGen(tokenId, 0, 1);
            if (!allowedDnaVersions[uint256(dnaVersion)]) { 
                continue;
            }

            int256 dnaBoost = IKondux(konduxERC721kNFT).readGen(tokenId, 1, 2) * 100;
            if (dnaBoost < 0) {
                dnaBoost = 0;
            }

            for (uint256 j = 0; j < 5; j++) {
                if (uint256(dnaBoost) > top5Bonuses[j]) {
                    uint256 temp = top5Bonuses[j];
                    top5Bonuses[j] = uint256(dnaBoost);
                    dnaBoost = int256(temp);

                    uint256 tempId = top5Ids[j];
                    top5Ids[j] = tokenId;
                    tokenId = tempId;
                }
            }
        }

        return (top5Bonuses, top5Ids);
    }

    function getMaxTop5BonusesAndIds(address _staker) 
        public 
        view 
        returns (uint256[] memory top5Bonuses, uint256[] memory top5Ids) 
    {
        uint256 kNFTBalance = IERC721(konduxERC721kNFT).balanceOf(_staker);
        top5Bonuses = new uint256[](5);
        top5Ids = new uint256[](5);

        for (uint256 i = 0; i < kNFTBalance; i++) {
            uint256 tokenId = IERC721Enumerable(konduxERC721kNFT).tokenOfOwnerByIndex(_staker, i);

            int256 dnaVersion = IKondux(konduxERC721kNFT).readGen(tokenId, 0, 1);
            if (!allowedDnaVersions[uint256(dnaVersion)]) { 
                continue;
            }

            int256 dnaBoost = IKondux(konduxERC721kNFT).readGen(tokenId, 1, 2) * 100;
            if (dnaBoost < 0) {
                dnaBoost = 0;
            }

            for (uint256 j = 0; j < 5; j++) {
                if (uint256(dnaBoost) > top5Bonuses[j]) {
                    uint256 temp = top5Bonuses[j];
                    top5Bonuses[j] = uint256(dnaBoost);
                    dnaBoost = int256(temp);

                    uint256 tempId = top5Ids[j];
                    top5Ids[j] = tokenId;
                    tokenId = tempId;
                }
            }
        }

        return (top5Bonuses, top5Ids);
    }

    function calculateKNFTBoostPercentage(address _staker, uint256 _stakeId) public view returns (uint256 boostPercentage) {
        if (_isV1Deposit(_stakeId) && !isV1Migrated[_stakeId]) {
            // We call V1’s version
            return stakingV1.calculateKNFTBoostPercentage(_staker, _stakeId); 
        }

        (uint256[] memory top5Bonuses, ) = getTop5BonusesAndIds(_staker, _stakeId);
        for (uint256 i = 0; i < 5; i++) {
            boostPercentage += top5Bonuses[i];
        }
        return boostPercentage;
    }

    function calculateMaxKNFTBoostPercentage(address _staker) public view returns (uint256 boostPercentage) {
        (uint256[] memory top5Bonuses, ) = getMaxTop5BonusesAndIds(_staker);
        for (uint256 i = 0; i < 5; i++) {
            boostPercentage += top5Bonuses[i];
        }
        return boostPercentage;
    }

    /**
     * @dev Returns the total boost % combining Founders NFT, kNFT, timelock, etc.  
     *      If deposit is in V1, we call V1’s `calculateBoostPercentage` directly 
     *      (which presumably also does the Founders/kNFT/timelock logic).
     *      Once migrated or originally V2, we do your V2 logic.
     */
    function calculateBoostPercentage(address _staker, uint _stakeId) public view returns (uint256 boostPercentage) {
        // If deposit is recognized as a V1 deposit and not migrated yet:
        if (_isV1Deposit(_stakeId) && !isV1Migrated[_stakeId]) {
            // We call V1’s version
            return stakingV1.calculateBoostPercentage(_staker, _stakeId);
        }

        // Otherwise, use the local V2 logic:
        Staker memory deposit_ = userDeposits[_stakeId];

        // Start from 100% = divisorERC20
        boostPercentage = divisorERC20[deposit_.token];

        // Founders NFT
        if (IERC721(konduxERC721Founders).balanceOf(_staker) > 0) {
            boostPercentage += foundersRewardBoostERC20[deposit_.token];
        }

        // kNFT
        if (IERC721(konduxERC721kNFT).balanceOf(_staker) > 0) {
            // Here we call our V2 function for kNFT
            boostPercentage += calculateKNFTBoostPercentage(_staker, _stakeId); 
        }

        // Timelock
        if (deposit_.timelockCategory > 0) {
            boostPercentage += timelockCategoryBoost[deposit_.timelockCategory];
        }
        return boostPercentage;
    }

    /**
     * @dev Return several fields for a deposit in one call.
     */
    function getDepositDetails(address _staker, uint _stakeId)
        public
        view
        returns (
            uint256 _timelock,
            uint256 _depositTimestamp,
            uint8 _timelockCategory,
            uint256 _stake,
            uint256 _unclaimedRewards,
            uint256 _boostPercentage
        )
    {
        _timelock = getTimelock(_stakeId);
        _depositTimestamp = getDepositTimestamp(_stakeId);
        _timelockCategory = getTimelockCategory(_stakeId);
        (_stake, _unclaimedRewards) = getDepositInfo(_stakeId);
        _boostPercentage = calculateBoostPercentage(_staker, _stakeId);
    }
}
 