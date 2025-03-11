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
 * @notice Minimal interface for calling the Treasury contract.
 */
interface ITreasury {
    function deposit(uint256 _amount, address _token) external;
    function withdraw(uint256 _amount, address _token) external;
}

/**
 * @title External Usage Oracle
 * @notice This interface can be implemented by a Chainlink oracle or custom usage tracker.
 */
interface IUsageOracle {
    function getUsage(address user) external view returns (uint256);
}

/**
 * @title KonduxTieredPayments
 * @dev A flexible micropayment contract that:
 *  - Allows any user to deposit stablecoins with time-lock
 *  - Allows providers to register with tier-based pricing and a custom royalty
 *  - Deducts usage cost across multiple tiers
 *  - Applies optional NFT-based discounts
 *  - Routes the provider’s share to their balance and the royalty to Kondux
 *  - Integrates with a usage oracle
 */
contract KonduxTieredPayments is AccessControl {
    /* ========== ROLES ========== */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant UPDATER_ROLE  = keccak256("UPDATER_ROLE"); // e.g. backend or oracle updaters

    /* ========== STRUCTS ========== */

    /**
     * @dev Stores deposit information for each user.
     */
    struct UserPayment {
        // total tokens deposited in the treasury on behalf of the user
        uint256 totalDeposited;
        // total usage cost consumed so far
        uint256 totalUsed;
        // time at which the user last deposited (start of lock)
        uint256 depositTime;
        // whether the deposit is active
        bool active;
    }

    /**
     * @dev Defines a tier with usage threshold and cost per usage unit.
     * E.g., up to 1,000 units at X cost, then up to next threshold at Y cost, etc.
     */
    struct Tier {
        uint256 usageThreshold; 
        uint256 costPerUnit;    
    }

    /**
     * @dev Provider configuration, including:
     *  - whether they're registered
     *  - the royalty basis points (BPS)
     *  - fallbackRate if usage exceeds their highest tier
     */
    struct ProviderInfo {
        bool registered;     
        uint256 royaltyBps;  // e.g., 100 = 1%, 500 = 5%
        uint256 fallbackRate; // cost per unit if usage is above the last tier threshold
    }

    /* ========== STATE ========== */

    // Treasury contract where all funds will be deposited
    ITreasury public treasury;

    // Allowed stablecoins
    mapping(address => bool) public stablecoinAccepted;

    // Tracks each user's deposit & usage
    mapping(address => UserPayment) public userPayments;

    // Tracks each provider's info
    mapping(address => ProviderInfo) public providers;

    // For each provider, store an array of Tiers
    mapping(address => Tier[]) public providerTiers;

    // Tracks how much each provider can withdraw (accumulated earnings)
    mapping(address => uint256) public providerBalances;

    // Address receiving the royalty if provider does not override it or for Kondux
    address public konduxRoyaltyAddress;

    // Accumulates royalty for Kondux if the provider is using the default royalty
    uint256 public konduxRoyaltyBalance;

    // If "nftContracts" is non-empty, user might get a discount if they hold at least one NFT from any listed contract
    address[] public nftContracts;

    // Lock period for deposits (in seconds). E.g. 1 day = 86400
    uint256 public lockPeriod;

    // Optional usage oracle for verifying usage externally
    IUsageOracle public usageOracle;

    // Default royalty in BPS if the provider does not set a `royaltyBps`. E.g., 100 = 1%.
    uint256 public defaultRoyaltyBps = 100;

    // Example discount rate (in BPS) if the user holds any NFT from `nftContracts`
    // You could make this per-provider if you want more customization.
    uint256 public nftDiscountBps = 2000; // 20%

    /* ========== EVENTS ========== */

    /** 
     * @notice Emitted when a user deposits stablecoins. 
     * @param user The user depositing.
     * @param token The stablecoin address.
     * @param amount The amount deposited.
     */
    event DepositMade(address indexed user, address indexed token, uint256 amount);

    /**
     * @notice Emitted when a user updates usage with a provider.
     * @param user The user whose usage was updated.
     * @param provider The provider receiving the micropayment.
     * @param cost The total cost in stable tokens deducted (includes royalty).
     * @param newTotalUsed The new total used amount for the user.
     */
    event UsageApplied(address indexed user, address indexed provider, uint256 cost, uint256 newTotalUsed);

    /**
     * @notice Emitted when a user withdraws unused funds after lock period.
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

    /**
     * @notice Emitted when a provider registers or updates their settings.
     * @param provider The provider address.
     * @param royaltyBps The new royalty BPS for this provider.
     * @param fallbackRate Cost per unit if usage exceeds final tier.
     */
    event ProviderRegistered(address indexed provider, uint256 royaltyBps, uint256 fallbackRate);

    /**
     * @notice Emitted when a provider sets or updates their tier array.
     * @param provider The provider address.
     * @param tiersLength The number of tiers set.
     */
    event ProviderTiersUpdated(address indexed provider, uint256 tiersLength);

    /**
     * @notice Emitted when a provider withdraws their accumulated earnings.
     * @param provider The provider address.
     * @param token The stablecoin being withdrawn.
     * @param amount The amount withdrawn.
     */
    event ProviderWithdrawn(address indexed provider, address indexed token, uint256 amount);

    /**
     * @notice Emitted when Kondux (royalty address) withdraws royalties.
     * @param token The stablecoin withdrawn.
     * @param amount The amount withdrawn.
     */
    event RoyaltyWithdrawn(address indexed token, uint256 amount);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @notice Sets up roles, the treasury, stablecoins, lock period, and Kondux royalty receiver.
     * @param _treasury Address of the deployed Treasury contract.
     * @param governor Address to be granted the GOVERNOR_ROLE.
     * @param _acceptedStablecoins List of stablecoins initially accepted.
     * @param _lockPeriod The initial lock period for deposits in seconds.
     * @param _konduxRoyaltyAddress The default address that receives royalties if not overridden by provider.
     */
    constructor(
        address _treasury,
        address governor,
        address[] memory _acceptedStablecoins,
        uint256 _lockPeriod,
        address _konduxRoyaltyAddress
    ) {
        require(_treasury != address(0), "Invalid treasury address");
        require(governor != address(0), "Invalid governor address");
        require(_konduxRoyaltyAddress != address(0), "Invalid royalty address");

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);

        treasury = ITreasury(_treasury);
        lockPeriod = _lockPeriod;
        konduxRoyaltyAddress = _konduxRoyaltyAddress;

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
     * @notice Update the lock period for deposits.
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
     * @notice Sets or updates the default royalty BPS if providers don't override.
     * @param _defaultRoyaltyBps The new default BPS. E.g. 100 = 1%.
     */
    function setDefaultRoyaltyBps(uint256 _defaultRoyaltyBps)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        defaultRoyaltyBps = _defaultRoyaltyBps;
    }

    /**
     * @notice Sets or updates the NFT discount BPS applied if user holds any of the configured NFTs.
     * @param _nftDiscountBps The discount in basis points. E.g. 2000 = 20%.
     */
    function setNFTDiscountBps(uint256 _nftDiscountBps)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        nftDiscountBps = _nftDiscountBps;
    }

    /**
     * @notice Sets or updates the Kondux royalty address (when default royalty is used).
     * @param _konduxRoyaltyAddress The new royalty receiver.
     */
    function setKonduxRoyaltyAddress(address _konduxRoyaltyAddress)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(_konduxRoyaltyAddress != address(0), "Invalid royalty address");
        konduxRoyaltyAddress = _konduxRoyaltyAddress;
    }

    /* ========== PROVIDER-RELATED FUNCTIONS ========== */

    /**
     * @notice Registers or updates a provider's royalty and fallback rate.
     * @dev The provider can call this at any time to change their royalty or fallback rate.
     * @param royaltyBps The royalty in basis points for this provider (e.g. 200 = 2%).
     *                   If set to 0, the contract uses `defaultRoyaltyBps`.
     * @param fallbackRate The cost per usage unit if usage surpasses the last tier threshold.
     */
    function registerProvider(uint256 royaltyBps, uint256 fallbackRate) external {
        // No strict upper limit on royaltyBps, but typically <= 10000
        // The fallbackRate can be zero if the provider wants 0 cost above final tier
        ProviderInfo storage info = providers[msg.sender];
        info.registered = true;
        info.royaltyBps = royaltyBps;
        info.fallbackRate = fallbackRate;

        emit ProviderRegistered(msg.sender, royaltyBps, fallbackRate);
    }

    /**
     * @notice Unregisters a provider so they can no longer receive new usage payments.
     * @dev Existing balances remain withdrawable.
     */
    function unregisterProvider() external {
        ProviderInfo storage info = providers[msg.sender];
        require(info.registered, "Provider not registered");

        info.registered = false;
        info.royaltyBps = 0;
        info.fallbackRate = 0;

        // Optionally remove their tiers if you'd like
        delete providerTiers[msg.sender];
        // Not emitting an event for unregistration, but you could do so.
    }

    /**
     * @notice Sets or updates the tier array for the provider.
     * @dev Tiers should be in ascending order of usageThreshold.
     * @param usageThresholds Array of usage thresholds (ascending).
     * @param costsPerUnit Array of cost-per-unit corresponding to each threshold.
     */
    function setProviderTiers(
        uint256[] calldata usageThresholds,
        uint256[] calldata costsPerUnit
    ) external {
        ProviderInfo storage info = providers[msg.sender];
        require(info.registered, "Not a registered provider");
        require(
            usageThresholds.length == costsPerUnit.length,
            "Tier array mismatch"
        );

        delete providerTiers[msg.sender];

        uint256 lastThreshold = 0;
        for (uint256 i = 0; i < usageThresholds.length; i++) {
            // Ensure ascending thresholds
            require(
                usageThresholds[i] > lastThreshold,
                "Thresholds not ascending"
            );
            lastThreshold = usageThresholds[i];

            providerTiers[msg.sender].push(
                Tier({
                    usageThreshold: usageThresholds[i],
                    costPerUnit: costsPerUnit[i]
                })
            );
        }

        emit ProviderTiersUpdated(msg.sender, usageThresholds.length);
    }

    /**
     * @notice Withdraw the provider's accumulated balance (earnings) from the Treasury.
     * @param token The stablecoin to withdraw.
     */
    function providerWithdraw(address token)
        external
        onlyAcceptedStablecoin(token)
    {
        uint256 balance = providerBalances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        require(providers[msg.sender].registered, "Not a registered provider");

        providerBalances[msg.sender] = 0;

        // Pull from treasury to the contract, then send to the provider
        treasury.withdraw(balance, token);
        IERC20(token).transfer(msg.sender, balance);

        emit ProviderWithdrawn(msg.sender, token, balance);
    }

    /**
     * @notice Withdraw all accumulated default royalties (from providers using 0 BPS) to konduxRoyaltyAddress.
     * @param token The stablecoin to withdraw.
     */
    function withdrawRoyalty(address token)
        external
        onlyAcceptedStablecoin(token)
    {
        require(msg.sender == konduxRoyaltyAddress, "Only Kondux can withdraw royalty");
        uint256 balance = konduxRoyaltyBalance;
        require(balance > 0, "No royalty balance");

        // Reset local royalty balance
        konduxRoyaltyBalance = 0;

        // Pull from treasury to this contract, then forward to Kondux
        treasury.withdraw(balance, token);
        IERC20(token).transfer(konduxRoyaltyAddress, balance);

        emit RoyaltyWithdrawn(token, balance);
    }

    /* ========== DEPOSIT/WITHDRAW USER FUNCTIONS ========== */

    /**
     * @notice Deposit stablecoins for usage, locked until `lockPeriod` expires.
     * @dev User must have approved the treasury to transfer 'amount' of 'token' first.
     * @param token The accepted stablecoin address.
     * @param amount The amount of stablecoins to deposit.
     */
    function deposit(address token, uint256 amount)
        external
        onlyAcceptedStablecoin(token)
    {
        require(amount > 0, "Deposit must be > 0");

        // Retrieve or create the user payment record
        UserPayment storage payment = userPayments[msg.sender];

        IERC20 tokenImpl = IERC20(token);

        // Transfer tokens into the treasury
        require(
            tokenImpl.allowance(msg.sender, address(this)) >= amount,
            "Insufficient token allowance"
        );
        require(
            tokenImpl.balanceOf(msg.sender) >= amount,
            "Insufficient token balance"
        );

        // Transfer tokens from user to treasury
        bool success = tokenImpl.transferFrom(msg.sender, address(treasury), amount);
        require(success, "Token transfer failed"); 

        payment.totalDeposited += amount;
        payment.active = true;
        payment.depositTime = block.timestamp;

        emit DepositMade(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw any unused tokens after verifying usage and ensuring lock has matured.
     * @param token The stablecoin address to withdraw.
     */
    function withdrawUnused(address token)
        external
        onlyAcceptedStablecoin(token)
    {
        UserPayment storage payment = userPayments[msg.sender];
        require(payment.active, "No active deposit");
        require(block.timestamp >= payment.depositTime + lockPeriod, "Deposit still locked");

        // Optionally check usage from an external oracle
        uint256 externalUsage = 0;
        if (address(usageOracle) != address(0)) {
            externalUsage = usageOracle.getUsage(msg.sender);
        }

        // The higher of local totalUsed or external usage is final
        uint256 finalUsage = payment.totalUsed;
        if (externalUsage > finalUsage) {
            finalUsage = externalUsage;
        }

        // If final usage cost >= deposit, nothing left
        if (finalUsage >= payment.totalDeposited) {
            revert("No unused funds left");
        }

        uint256 leftover = payment.totalDeposited - finalUsage;

        // Mark deposit as used up to finalUsage
        payment.totalUsed = finalUsage;
        payment.totalDeposited = finalUsage; // effectively consumed

        // Withdraw from treasury to this contract, then forward to user
        treasury.withdraw(leftover, token);
        IERC20(token).transfer(msg.sender, leftover);

        emit UnusedWithdrawn(msg.sender, token, leftover);
    }

    /* ========== TIERED USAGE FUNCTIONS ========== */

    /**
     * @notice Called by an authorized UPDATER_ROLE (or user themselves) to apply usage to a provider.
     * @param user The user paying for usage.
     * @param provider The provider receiving the micropayment for usage.
     * @param usageUnits The number of usage units to apply.
     */
    function applyUsage(address user, address provider, uint256 usageUnits)
        external
        onlyRole(UPDATER_ROLE)
    {
        _applyUsageInternal(user, provider, usageUnits);
    }

    /**
     * @notice Users can self-report usage directly, if that fits your model.
     * @param provider The provider to pay for usage.
     * @param usageUnits The number of usage units to apply.
     */
    function selfApplyUsage(address provider, uint256 usageUnits) external {
        _applyUsageInternal(msg.sender, provider, usageUnits);
    }

    // ========== HELPER FUNCTIONS ========== //
    /**
     * @notice Returns nftContracts array
     * @return The array of NFT contract addresses.
     */
    function getNFTContracts() external view returns (address[] memory) {
        return nftContracts;
    }

    /* ========== INTERNAL LOGIC ========== */

    /**
     * @dev Internal function to apply usage from a user to a provider.
     * @param user The user paying for usage.
     * @param provider The provider being paid.
     * @param usageUnits The usage units to be billed.
     */
    function _applyUsageInternal(address user, address provider, uint256 usageUnits) internal {
        require(usageUnits > 0, "Usage must be > 0");

        UserPayment storage payment = userPayments[user];
        require(payment.active, "No active deposit");
        require(providers[provider].registered, "Provider not registered");

        // 1. Compute the cost by iterating over the provider's tiers
        uint256 baseCost = _computeTieredCost(usageUnits, provider);

        // 2. Apply NFT discount if user holds any listed NFT (example 20%).
        uint256 discountedCost = baseCost;
        if (_userHasAnyNFT(user) && baseCost > 0) {
            uint256 discountAmount = (baseCost * nftDiscountBps) / 10000;
            discountedCost = baseCost - discountAmount;
        }

        if (discountedCost == 0) {
            // No charge
            emit UsageApplied(user, provider, 0, payment.totalUsed);
            return;
        }

        // 3. Deduct the royalty from the discounted cost.
        // If provider's royaltyBps is zero, use defaultRoyaltyBps.
        uint256 actualRoyaltyBps = providers[provider].royaltyBps;
        if (actualRoyaltyBps == 0) {
            actualRoyaltyBps = defaultRoyaltyBps;
        }

        uint256 royalty = (discountedCost * actualRoyaltyBps) / 10000;
        uint256 providerShare = discountedCost - royalty;

        // 4. Ensure user has enough deposit
        uint256 newTotalUsed = payment.totalUsed + discountedCost;
        require(newTotalUsed <= payment.totalDeposited, "Insufficient deposit for usage");

        // 5. Update user's usage, provider balance, and royalty balance
        payment.totalUsed = newTotalUsed;
        providerBalances[provider] += providerShare;

        // If the provider sets royaltyBps > 0, that portion belongs to the provider’s chosen arrangement?
        // This snippet assumes the royalty always goes to Kondux. If you want each provider to have a custom
        // "royalty receiver," you'd store that in `ProviderInfo`. But for demonstration, we track it in
        // konduxRoyaltyBalance if the provider's not using a custom address. 
        konduxRoyaltyBalance += royalty;

        emit UsageApplied(user, provider, discountedCost, newTotalUsed);
    }

    /**
     * @dev Computes the total cost for the given usage units by iterating through the provider's tier array.
     *      If usage extends past the last tier threshold, the remainder is charged at the provider's fallbackRate.
     */
    function _computeTieredCost(uint256 usageUnits, address provider)
        internal
        view
        returns (uint256 cost)
    {
        Tier[] storage tiers = providerTiers[provider];
        uint256 remaining = usageUnits;
        cost = 0;

        for (uint256 i = 0; i < tiers.length; i++) {
            // If the provider's tier is "up to X usage," we see how many units fit here
            uint256 tierCap = tiers[i].usageThreshold;
            uint256 unitsToCharge = 0;

            // If there's a previous tier, tierCap is relative to previous threshold or absolute from 0.
            // For simplicity, we treat it as the difference from the previous tier or ascending threshold.
            // e.g. if tier 0 is up to 1000, tier 1 is up to 3000, etc.
            // We must interpret the "up to usageThreshold" cumulatively or incrementally.
            // Below logic assumes a "cumulative" threshold, e.g. tier 0 => 1000, tier 1 => 3000 total usage, etc.

            // If we are on the first tier, usage <= tierCap. Next tier might say up to 3000 total usage. 
            // So we check difference between tier i and tier i-1:
            uint256 prevThreshold = (i == 0) ? 0 : tiers[i - 1].usageThreshold;
            uint256 tierSize = tierCap - prevThreshold;

            if (remaining == 0) break;

            if (remaining <= tierSize) {
                unitsToCharge = remaining;
            } else {
                unitsToCharge = tierSize;
            }

            cost += unitsToCharge * tiers[i].costPerUnit;
            remaining -= unitsToCharge;
        }

        // If there's still remaining usage above the last tier, charge at fallbackRate
        if (remaining > 0) {
            uint256 fallbackRate = providers[provider].fallbackRate;
            cost += remaining * fallbackRate;
        }
    }

    /**
     * @dev Checks if a user holds at least 1 NFT from the listed NFT contracts.
     * @param user The user being checked.
     * @return True if user has at least one NFT from any contract in `nftContracts`.
     */
    function _userHasAnyNFT(address user) internal view returns (bool) {
        for (uint256 i = 0; i < nftContracts.length; i++) {
            if (IERC721(nftContracts[i]).balanceOf(user) > 0) {
                return true;
            }
        }
        return false;
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice Returns whether the user holds at least one NFT from the listed contracts.
     * @param user The user being checked.  
     * @return True if user holds at least one NFT from any contract in `nftContracts`.
     */
    function userHasAnyNFT(address user) external view returns (bool) {
        return _userHasAnyNFT(user);
    }

    /**
     * @notice Returns whether the user's deposit is still locked.
     * @param user The address of the user.
     * @return locked True if user deposit is locked, otherwise false.
     */
    function isLocked(address user) external view returns (bool locked) {
        UserPayment memory payment = userPayments[user];
        locked = (block.timestamp < (payment.depositTime + lockPeriod));
    }

    /**
     * @notice Returns the unspent portion of the user's deposit by internal records (no oracle check).
     * @param user The address of the user.
     * @return leftover The deposit amount minus usage so far.
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
     */
    function getUserPayment(address user) external view returns (UserPayment memory) {
        return userPayments[user];
    }

    /**
     * @notice Returns provider info, including if they're registered, their royalty, and fallback rate.
     * @param provider The provider's address.
     */
    function getProviderInfo(address provider) external view returns (ProviderInfo memory) {
        return providers[provider];
    }

    /**
     * @notice Returns the tiers for a given provider.
     * @param provider The provider's address.
     */
    function getProviderTiers(address provider) external view returns (Tier[] memory) {
        return providerTiers[provider];
    }

    /**
     * @notice Returns the provider's accumulated balance.
     * @param provider The provider address.
     */
    function getProviderBalance(address provider) external view returns (uint256) {
        return providerBalances[provider];
    }

    /**
     * @notice Returns the current royalty balance waiting to be withdrawn by Kondux (for providers using 0 BPS).
     */
    function getKonduxRoyaltyBalance() external view returns (uint256) {
        return konduxRoyaltyBalance;
    }
}
