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
 * @title KonduxMeteredPayments
 * @dev A metered micropayment contract that:
 *  - Allows users to deposit stablecoins
 *  - Deducts usage on a per-unit basis (metered)
 *  - Gives optional NFT-based discounts
 *  - Enforces a 1% royalty fee to Kondux
 *  - Locks deposits until a certain period
 *  - Integrates with an optional external usage oracle
 *  - Uses a Treasury for all fund movements
 */
contract KonduxMeteredPayments is AccessControl {
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
     * @dev Stores provider configuration.
     */
    struct ProviderInfo {
        bool registered;    // whether the provider is registered
        uint256 ratePerUnit; // cost per usage unit (before discounts/royalty)
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

    // Tracks how much each provider can withdraw (accumulated earnings)
    mapping(address => uint256) public providerBalances;

    // Address receiving the 1% royalty (e.g. Kondux or a treasury)
    address public konduxRoyaltyAddress;

    // Accumulates royalties for Kondux
    uint256 public konduxRoyaltyBalance;

    // NFT contracts used for discount or gating (simple approach)
    // If non-empty, user must hold at least 1 NFT from at least one of these addresses to get a discount.
    // (Or you can enforce gating logic differently.)
    address[] public nftContracts;

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
     * @notice Emitted when a user updates usage (metered).
     * @param user The user whose usage was updated.
     * @param provider The provider receiving the usage payment.
     * @param cost The total cost in stable tokens deducted from the user’s deposit (includes royalty).
     * @param newTotalUsed The new total used amount for the user.
     */
    event UsageApplied(
        address indexed user,
        address indexed provider,
        uint256 cost,
        uint256 newTotalUsed
    );

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
     * @notice Emitted when a provider registers or updates their rate.
     * @param provider The provider address.
     * @param ratePerUnit The new rate per usage unit.
     */
    event ProviderRegistered(address indexed provider, uint256 ratePerUnit);

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
     * @notice Sets up roles, the treasury, stablecoins, lock period, and the Kondux royalty receiver.
     * @param _treasury Address of the deployed Treasury contract.
     * @param governor Address to be granted the GOVERNOR_ROLE.
     * @param _acceptedStablecoins List of stablecoins initially accepted.
     * @param _lockPeriod The initial lock period for deposits in seconds.
     * @param _konduxRoyaltyAddress The address that receives the 1% royalty.
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
     * @notice Sets or updates the address that receives royalties (Kondux).
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
     * @notice Registers or updates a provider's rate per usage unit.
     * @dev Any user can call this to become a provider or update their rate.
     * @param ratePerUnit The cost per usage unit in stable token units (before discount & royalty).
     */
    function registerProvider(uint256 ratePerUnit) external {
        require(ratePerUnit > 0, "Rate must be > 0");

        providers[msg.sender] = ProviderInfo({
            registered: true,
            ratePerUnit: ratePerUnit
        });

        emit ProviderRegistered(msg.sender, ratePerUnit);
    }

    /**
     * @notice Unregisters a provider so they can no longer receive new usage payments.
     * @dev Existing balances remain withdrawable.
     */
    function unregisterProvider() external {
        ProviderInfo storage info = providers[msg.sender];
        require(info.registered, "Provider not registered");

        info.registered = false;
        info.ratePerUnit = 0;
        // Optionally emit an event or simply rely on logs from registerProvider with rate=0
    }

    /**
     * @notice Withdraw the provider's accumulated balance (earnings) from the Treasury.
     * @param token The stablecoin to withdraw (must be accepted).
     */
    function providerWithdraw(address token)
        external
        onlyAcceptedStablecoin(token)
    {
        uint256 balance = providerBalances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        require(providers[msg.sender].registered == true, "Not a registered provider");

        providerBalances[msg.sender] = 0;

        // Now pull from treasury to the contract, then send to the provider
        treasury.withdraw(balance, token);

        // The treasury withdraw transfers to this contract, so forward to provider:
        IERC20(token).transfer(msg.sender, balance);

        emit ProviderWithdrawn(msg.sender, token, balance);
    }

    /**
     * @notice Withdraw all accumulated royalties (1% portion) to Kondux.
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

        // Transfer tokens into the treasury
        treasury.deposit(amount, token);

        payment.totalDeposited += amount;
        payment.active = true;
        payment.depositTime = block.timestamp;

        emit DepositMade(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw any unused tokens after verifying usage and ensuring lock has matured.
     * @param token The stablecoin address to withdraw (must be the same as initially deposited).
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
        payment.totalDeposited = finalUsage; // effectively consumed the deposit

        // Now withdraw from treasury to this contract, then forward to user
        treasury.withdraw(leftover, token);
        IERC20(token).transfer(msg.sender, leftover);

        emit UnusedWithdrawn(msg.sender, token, leftover);
    }

    /* ========== METERED USAGE FUNCTIONS ========== */

    /**
     * @notice Called by an authorized UPDATER_ROLE (or the user themselves) to apply usage to a given provider.
     * @param provider The provider receiving the micropayment for usage.
     * @param usageUnits The number of usage units to apply.
     */
    function applyUsage(address provider, uint256 usageUnits)
        external
        onlyRole(UPDATER_ROLE)
    {
        _applyUsageInternal(msg.sender, provider, usageUnits);
    }

    /**
     * @notice Users can self-report usage directly, if that fits your model.
     * @param provider The provider to pay for usage.
     * @param usageUnits The number of usage units to apply.
     */
    function selfApplyUsage(address provider, uint256 usageUnits) external {
        _applyUsageInternal(msg.sender, provider, usageUnits);
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

        // 1. Base cost = usageUnits * provider rate
        uint256 baseCost = usageUnits * providers[provider].ratePerUnit;

        // 2. Apply NFT discount if user holds any of the configured NFTs
        uint256 discountedCost = baseCost;
        if (_userHasAnyNFT(user) && baseCost > 0) {
            // Example discount: 20% if user has at least 1 NFT from the list
            uint256 discountBps = 2000; // 20%
            uint256 discountAmount = (baseCost * discountBps) / 10000;
            discountedCost = baseCost - discountAmount;
        }

        // 3. Deduct 1% royalty for Kondux
        //    i.e., if discountedCost is 100, then 1 goes to Kondux, 99 to the provider
        //    user deposit is reduced by the entire `discountedCost`.
        if (discountedCost == 0) {
            // No cost to split
            emit UsageApplied(user, provider, 0, payment.totalUsed);
            return;
        }

        uint256 royalty = discountedCost / 100; // 1% (integer division is typical; leftover is for provider)
        uint256 providerShare = discountedCost - royalty;

        // 4. Ensure user has enough deposit left
        //    We track usage in "totalUsed" to compare with "totalDeposited"
        uint256 newTotalUsed = payment.totalUsed + discountedCost;
        require(newTotalUsed <= payment.totalDeposited, "Insufficient deposit for usage");

        // 5. Update ledger
        payment.totalUsed = newTotalUsed;
        // Add to provider's balance
        providerBalances[provider] += providerShare;
        // Accumulate royalty
        konduxRoyaltyBalance += royalty;

        emit UsageApplied(user, provider, discountedCost, newTotalUsed);
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
     * @notice Returns whether the user's deposit is still locked.
     * @param user The address of the user.
     * @return locked True if user deposit is locked, otherwise false.
     */
    function isLocked(address user) external view returns (bool locked) {
        UserPayment memory payment = userPayments[user];
        locked = (block.timestamp < (payment.depositTime + lockPeriod));
    }

    /**
     * @notice Returns the unspent portion of the user's deposit by internal records (no oracle).
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
     * @notice Returns provider info, including if they're registered and their rate.
     * @param provider The provider's address.
     */
    function getProviderInfo(address provider) external view returns (ProviderInfo memory) {
        return providers[provider];
    }

    /**
     * @notice Returns the provider's accumulated balance.
     * @param provider The provider address.
     */
    function getProviderBalance(address provider) external view returns (uint256) {
        return providerBalances[provider];
    }

    /**
     * @notice Returns the current royalty balance waiting to be withdrawn by Kondux.
     */
    function getKonduxRoyaltyBalance() external view returns (uint256) {
        return konduxRoyaltyBalance;
    }
}
