// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title OpenZeppelin Interfaces
 */
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title External Treasury Interface
 * @notice Minimal interface for calling the provided Treasury contract.
 */
interface ITreasury {
    function deposit(uint256 _amount, address _token) external;
    function withdraw(uint256 _amount, address _token) external;
}

/**
 * @title External Usage Oracle (optional example)
 * @notice This interface can be implemented by a Chainlink oracle or custom usage tracker.
 */
interface IUsageOracle {
    function getUsage(address user) external view returns (uint256);
}

/**
 * @title KonduxMicropayment
 * @dev Manages tiered micro-payments, NFT-gating, usage-based metering, and time-locked deposits
 */
contract KonduxMicropayment is AccessControl {
    /* ========== ROLES ========== */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant UPDATER_ROLE  = keccak256("UPDATER_ROLE"); // e.g. backend or oracle updaters

    /* ========== STRUCTS ========== */

    /**
     * @dev Stores deposit and usage information for each user.
     */
    struct UserPayment {
        // total tokens deposited in the treasury on behalf of the user
        uint256 totalDeposited; 
        // total usage cost consumed
        uint256 totalUsed;      
        // time at which deposit was locked
        uint256 depositTime;    
        // whether the deposit is active
        bool active;            
    }

    /**
     * @dev Defines a tier with usage threshold and cost per usage unit.
     *      This is an example structure; adapt for your pricing.
     */
    struct Tier {
        uint256 usageThreshold; // e.g. up to 1,000 units
        uint256 costPerUnit;    // cost in smallest stablecoin units (e.g. 1e6 for USDC=1)
    }

    /* ========== STATE ========== */

    // Treasury contract where all funds will be deposited
    ITreasury public treasury;

    // Allowed stablecoins
    mapping(address => bool) public stablecoinAccepted;

    // Basic NFT gating configuration
    // If "nftContracts" is non-empty, user must hold at least 1 NFT in *any* of these contracts for discount/gate
    address[] public nftContracts;

    // Tracks each user's deposit & usage
    mapping(address => UserPayment) public userPayments;

    // Tiers array (index 0 is the lowest tier, last index is the highest)
    Tier[] public tiers;

    // Lock period for deposits (in seconds). E.g. 1 day = 86400
    uint256 public lockPeriod;

    // Optional usage oracle for verifying usage externally
    IUsageOracle public usageOracle;

    /* ========== EVENTS ========== */

    /** 
     * @notice Emitted when a user deposits stablecoins. 
     * @param user The user depositing.
     * @param token The stablecoin address.
     * @param amount The amount deposited.
     */
    event DepositMade(address indexed user, address indexed token, uint256 amount);

    /** 
     * @notice Emitted when usage is updated for a user.
     * @param user The user whose usage was updated.
     * @param cost The cost in stable tokens deducted from the user’s deposit.
     * @param newTotalUsed The new total used amount for the user.
     */
    event UsageApplied(address indexed user, uint256 cost, uint256 newTotalUsed);

    /**
     * @notice Emitted when a user withdraws unused funds.
     * @param user The user withdrawing.
     * @param token The stablecoin address.
     * @param amount The amount withdrawn.
     */
    event UnusedWithdrawn(address indexed user, address indexed token, uint256 amount);

    /** 
     * @notice Emitted when the usage oracle is updated.
     * @param newOracle The address of the new usage oracle.
     */
    event UsageOracleUpdated(address newOracle);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Sets up roles, the treasury, and initial stablecoins.
     * @param _treasury Address of the deployed Treasury contract.
     * @param governor Address to be granted the GOVERNOR_ROLE.
     * @param _acceptedStablecoins List of stablecoins initially accepted.
     * @param _lockPeriod The initial lock period for deposits in seconds.
     */
    constructor(
        address _treasury,
        address governor,
        address[] memory _acceptedStablecoins,
        uint256 _lockPeriod
    ) {
        require(_treasury != address(0), "Invalid treasury address");
        require(governor != address(0), "Invalid governor address");

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);

        treasury = ITreasury(_treasury);
        lockPeriod = _lockPeriod;

        // Mark initial stablecoins as accepted
        for (uint256 i = 0; i < _acceptedStablecoins.length; i++) {
            stablecoinAccepted[_acceptedStablecoins[i]] = true;
        }
    }

    /* ========== MODIFIERS ========== */

    /**
     * @dev Checks that a token is a stablecoin accepted by the contract.
     */
    modifier onlyAcceptedStablecoin(address token) {
        require(stablecoinAccepted[token], "Stablecoin not accepted");
        _;
    }

    /* ========== GOVERNOR-ONLY CONFIGURATION ========== */

    /**
     * @notice Add or remove a stablecoin from the accepted list.
     * @dev Only callable by GOVERNOR_ROLE.
     * @param token The stablecoin address.
     * @param accepted True if it is accepted, false if not.
     */
    function setStablecoinAccepted(address token, bool accepted)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        stablecoinAccepted[token] = accepted;
    }

    /**
     * @notice Set or update the lock period for deposits.
     * @dev Only callable by GOVERNOR_ROLE.
     * @param _lockPeriod The new lock period in seconds.
     */
    function setLockPeriod(uint256 _lockPeriod)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        lockPeriod = _lockPeriod;
    }

    /**
     * @notice Add or remove NFT contracts for gating/discount checks.
     * @dev Only callable by GOVERNOR_ROLE.
     * @param _nftContracts The full updated array of NFT contract addresses.
     */
    function setNFTContracts(address[] calldata _nftContracts)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        nftContracts = _nftContracts;
    }

    /**
     * @notice Sets the usage oracle contract address (optional).
     * @dev Only callable by GOVERNOR_ROLE.
     * @param _oracle Address of the usage oracle.
     */
    function setUsageOracle(address _oracle)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        usageOracle = IUsageOracle(_oracle);
        emit UsageOracleUpdated(_oracle);
    }

    /**
     * @notice Sets or updates the tiers.
     * @dev Only callable by GOVERNOR_ROLE. Clears old tiers and replaces them.
     * @param usageThresholds Array of usage thresholds (ascending).
     * @param costsPerUnit Array of cost-per-unit corresponding to each threshold.
     */
    function setTiers(
        uint256[] calldata usageThresholds,
        uint256[] calldata costsPerUnit
    )
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(
            usageThresholds.length == costsPerUnit.length && usageThresholds.length > 0,
            "Tier arrays mismatch or empty"
        );

        delete tiers;
        for (uint256 i = 0; i < usageThresholds.length; i++) {
            tiers.push(Tier({
                usageThreshold: usageThresholds[i],
                costPerUnit: costsPerUnit[i]
            }));
        }
    }

    /* ========== PUBLIC/EXTERNAL USER FUNCTIONS ========== */

    /**
     * @notice Deposit stablecoins on behalf of the caller, locked for the configured period.
     * @dev All tokens go directly to the Treasury contract.
     * @param token The accepted stablecoin address.
     * @param amount The amount of stablecoins to deposit.
     */
    function deposit(address token, uint256 amount)
        external
        onlyAcceptedStablecoin(token)
    {
        require(amount > 0, "Amount must be > 0");

        // If this is the first deposit or user re-deposits after usage
        UserPayment storage payment = userPayments[msg.sender];

        // Passive update: recalculate usage or discount if needed (example stub)
        // e.g., check if user's NFT holding changed, re-apply discount, etc.
        // In this example, we simply allow deposit.

        // -- All stablecoins flow to the treasury:
        // The treasury's deposit function itself will transfer tokens
        // from tx.origin => treasury. However, that requires the user to
        // have approved the treasury for 'amount'. The micropayment contract
        // is simply orchestrating the call.
        treasury.deposit(amount, token);

        // Update user payment info
        payment.totalDeposited += amount;
        payment.active = true;
        payment.depositTime = block.timestamp;

        emit DepositMade(msg.sender, token, amount);
    }

    /**
     * @notice Update usage for a user (reactive update from your backend or a data feed).
     * @dev Only callable by addresses with UPDATER_ROLE or user themselves.
     * @param user The address whose usage to update.
     * @param usageUnits The additional usage units to apply.
     */
    function applyUsage(address user, uint256 usageUnits)
        external
        onlyRole(UPDATER_ROLE)
    {
        _applyUsageInternal(user, usageUnits);
    }

    /**
     * @notice Users can self-report usage, if that fits your model.
     * @param usageUnits The additional usage units to apply.
     */
    function selfApplyUsage(uint256 usageUnits)
        external
    {
        _applyUsageInternal(msg.sender, usageUnits);
    }

    /**
     * @notice Withdraw any unused tokens after verifying usage and ensuring lock has matured.
     * @dev If usage from chainlink or internal accounting is incomplete, the final amount is calculated.
     * @param token The stablecoin address to withdraw (must be the same as initially deposited).
     */
    function withdrawUnused(address token)
        external
        onlyAcceptedStablecoin(token)
    {
        UserPayment storage payment = userPayments[msg.sender];
        require(payment.active, "No active deposit");
        // Must wait for lock to end
        require(
            block.timestamp >= payment.depositTime + lockPeriod,
            "Deposit still locked"
        );

        // Optionally check usage with an external oracle to ensure up-to-date usage
        uint256 externalUsage = 0;
        if (address(usageOracle) != address(0)) {
            externalUsage = usageOracle.getUsage(msg.sender);
        }

        // The higher of local totalUsed or external usage is taken as final usage
        uint256 finalUsage = payment.totalUsed;
        if (externalUsage > finalUsage) {
            finalUsage = externalUsage;
        }

        // Calculate how many units have been "paid for"
        // In this example, we assume 1 usage unit => 1 "paid" unit of cost, 
        // ignoring tiers. If you want to factor tier-based cost, you'd need 
        // to replicate the tier calculation using "finalUsage".
        uint256 costSoFar = _computeCost(finalUsage, msg.sender);

        // If costSoFar >= totalDeposited, no tokens left to withdraw
        if (costSoFar >= payment.totalDeposited) {
            revert("No unused funds left");
        }

        // The difference is unused and can be withdrawn
        uint256 unused = payment.totalDeposited - costSoFar;

        // Mark deposit as used up to costSoFar
        // If you want partial usage tracking, adjust logic as needed
        payment.totalUsed = finalUsage;
        payment.totalDeposited = costSoFar; // effectively "consumed" the deposit

        // Now, call the treasury to withdraw to this contract, then transfer to user
        treasury.withdraw(unused, token);

        // In the provided Treasury code, `withdraw()` 
        // does IKonduxERC20(_token).transfer(msg.sender, _amount);
        // which sends tokens to this contract (which is msg.sender of `withdraw()` call).
        // So we must forward them to the user:

        IERC20(token).transfer(msg.sender, unused);

        emit UnusedWithdrawn(msg.sender, token, unused);
    }

    /* ========== INTERNAL LOGIC ========== */

    /**
     * @notice Internal function to apply usage for a user (deduct cost from the ledger).
     * @param user The user whose usage is updated.
     * @param usageUnits The additional usage to apply.
     */
    function _applyUsageInternal(address user, uint256 usageUnits) internal {
        require(usageUnits > 0, "Usage must be > 0");
        UserPayment storage payment = userPayments[user];
        require(payment.active, "No active deposit for user");

        // Convert usageUnits to a cost based on user's discount/tier
        uint256 cost = _computeCost(usageUnits, user);

        // Add to totalUsed
        payment.totalUsed += cost;

        // Ensure we haven't exceeded the total deposit 
        // If we do exceed, it implies user is out of credit (you can revert or clamp usage).
        require(
            payment.totalUsed <= payment.totalDeposited,
            "Insufficient deposit for usage"
        );

        emit UsageApplied(user, cost, payment.totalUsed);
    }

    /**
     * @notice Computes the cost of usageUnits for a given user by factoring the user's NFT discount & tier rates.
     * @param usageUnits The number of usage units to cost out.
     * @param user The user for which to compute cost.
     * @return cost The final cost in stable token units.
     */
    function _computeCost(uint256 usageUnits, address user)
        internal
        view
        returns (uint256 cost)
    {
        // 1. Determine if user has any NFT from nftContracts => discount
        bool hasNFT = false;
        for (uint256 i = 0; i < nftContracts.length; i++) {
            if (IERC721(nftContracts[i]).balanceOf(user) > 0) {
                hasNFT = true;
                break;
            }
        }

        // 2. Calculate tier-based cost. 
        //    For simplicity, assume usageUnits is processed in a single chunk at one cost tier.
        //    In real scenarios, you may need to break usage across multiple tiers.
        uint256 tierCost = 0;
        for (uint256 i = 0; i < tiers.length; i++) {
            // If usageUnits is <= the tier threshold, use that cost
            if (usageUnits <= tiers[i].usageThreshold) {
                tierCost = tiers[i].costPerUnit * usageUnits;
                break;
            }
        }
        // If usage exceeded the largest threshold, charge at the highest tier
        if (tierCost == 0 && tiers.length > 0) {
            tierCost = tiers[tiers.length - 1].costPerUnit * usageUnits;
        }

        // 3. Apply discount if user has NFT 
        //    (For example, a 20% discount if they hold any NFT from the list).
        if (hasNFT) {
            uint256 discountBps = 2000; // 20% discount in basis points
            uint256 discountAmount = (tierCost * discountBps) / 10000;
            tierCost = tierCost - discountAmount;
        }

        cost = tierCost;
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice Returns whether a user is still locked.
     * @param user The address of the user.
     * @return locked True if user deposit is locked, otherwise false.
     */
    function isLocked(address user) external view returns (bool locked) {
        UserPayment memory payment = userPayments[user];
        locked = (block.timestamp < (payment.depositTime + lockPeriod));
    }

    /**
     * @notice Returns the leftover user balance (not yet spent) without external oracle check.
     * @param user The address of the user.
     * @return leftover The unspent portion of the user’s deposit by internal records.
     */
    function getLeftoverBalance(address user) external view returns (uint256 leftover) {
        UserPayment memory payment = userPayments[user];
        if (payment.totalDeposited <= payment.totalUsed) {
            return 0;
        }
        leftover = payment.totalDeposited - payment.totalUsed;
    }

    /**
     * @notice Returns the user payment info (convenience getter).
     * @param user The address of the user.
     * @return The UserPayment struct (totalDeposited, totalUsed, depositTime, active).
     */
    function getUserPayment(address user) external view returns (UserPayment memory) {
        return userPayments[user];
    }

    /**
     * @notice Returns the current length of the tier array.
     */
    function getTiersCount() external view returns (uint256) {
        return tiers.length;
    }
}
