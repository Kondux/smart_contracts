// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {StakingV2} from "../contracts/StakingV2.sol";
import {IStakingV1} from "../contracts/interfaces/IStakingV1.sol";

/// @notice Deploys `StakingV2` to Sepolia and backfills deposits from the
///         legacy mainnet `Staking` contract.
contract DeployStakingV2SepoliaImportScript is Script {
    uint8 internal constant MAX_TIMELOCK_CATEGORIES = 4;
    uint256 internal constant DEFAULT_IMPORT_BATCH = 25;

    address internal constant LEGACY_STAKING_V1 = 0x07E6F2239d6FbE2CE00747fCFb8344ebBf973BcC;

    address internal constant MAINNET_KONDUX = 0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1;

    address internal constant SEPOLIA_AUTHORITY = 0x685a13093cA561F531c93185B942a3f33385e14E;
    address internal constant SEPOLIA_KONDUX = 0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc;
    address internal constant SEPOLIA_TREASURY = 0xD5a6Af8F9C20CaF7872611d6773152aA50180f83;
    address internal constant SEPOLIA_FOUNDERS = 0x434fD7FEEc752c4BfA4a59d0272c503ffD313499;
    address internal constant SEPOLIA_KNFT = 0x5C7eD88DBBD99F513235A1911d41A5C57E2ffB78;
    address internal constant SEPOLIA_HELIX = 0xb94F89750d9889656a6D081A0F06cBd3FA3Ad04B;

    error UnknownToken(address legacyToken);

    struct AddressBook {
        string label;
        address authority;
        address konduxToken;
        address treasury;
        address foundersPass;
        address knft;
        address helix;
    }

    struct TokenConfig {
        address legacyToken;
        address targetToken;
        uint256 divisor;
        uint256 apr;
        uint256 compoundFreq;
        uint256 withdrawalFee;
        uint256 foundersBoost;
        uint256 knftBoost;
        uint256 ratio;
        uint256 minStake;
        uint8 decimals;
        uint256 earlyWithdrawalPenalty;
        uint256 totalWithdrawalFees;
        bool authorized;
    }

    struct LegacyGlobals {
        address helix;
        address founders;
        address knft;
        address treasury;
        uint256[MAX_TIMELOCK_CATEGORIES] timelockDurations;
        uint256[MAX_TIMELOCK_CATEGORIES] timelockBoosts;
        bool dnaVersion1Allowed;
    }

    struct LegacySnapshot {
        StakingV2.DepositImport[] deposits;
        TokenConfig[] tokens;
        LegacyGlobals globals;
        uint256 highestDepositId;
        uint256 nextDepositId;
        uint256 legacyNextDepositId;
        uint256 totalImported;
    }

    struct LegacyDepositRaw {
        address token;
        address staker;
        uint256 deposited;
        uint256 redeemed;
        uint256 timeOfLastUpdate;
        uint256 lastDepositTime;
        uint256 unclaimedRewards;
        uint256 timelock;
        uint8 timelockCategory;
        uint256 ratio;
        uint256 aprSnapshot;
    }

    function run() external {
        console2.log("=== DeployStakingV2SepoliaImport ===");
        console2.log("Active chain id:", block.chainid);

        string memory mainnetRpc = vm.envString("MAINNET_RPC_URL");
        string memory sepoliaRpc = vm.envString("SEPOLIA_RPC_URL");
        require(bytes(mainnetRpc).length != 0, "MAINNET_RPC_URL missing");
        require(bytes(sepoliaRpc).length != 0, "SEPOLIA_RPC_URL missing");

        uint256 importLimit = _loadImportLimit();

        console2.log("Using MAINNET_RPC_URL:", mainnetRpc);
        console2.log("Using SEPOLIA_RPC_URL:", sepoliaRpc);

        uint256 mainnetFork = vm.createFork(mainnetRpc);
        uint256 sepoliaFork = vm.createFork(sepoliaRpc);

        LegacySnapshot memory legacy = _collectLegacySnapshot(mainnetFork, importLimit);

        vm.selectFork(sepoliaFork);
        console2.log("Switched to Sepolia fork for deployment. Block:", block.number);

        AddressBook memory addresses = _resolveSepoliaAddresses();
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", deployer.balance);

        vm.startBroadcast(deployerKey);

        StakingV2 staking = new StakingV2(
            addresses.authority,
            addresses.konduxToken,
            addresses.treasury,
            addresses.foundersPass,
            addresses.knft,
            addresses.helix
        );
        console2.log("StakingV2 deployed at:", address(staking));

        _synchronizeGlobalConfig(staking, legacy.globals);
        _synchronizeTokenConfig(staking, legacy.tokens);
        _importDeposits(staking, legacy);

        vm.stopBroadcast();

        _logSummary(address(staking), addresses, legacy, importLimit);
    }

    function _collectLegacySnapshot(uint256 forkId, uint256 importLimit)
        internal
        returns (LegacySnapshot memory snapshot)
    {
        vm.selectFork(forkId);
        console2.log("Collecting legacy data from mainnet fork. Block:", block.number);

        IStakingV1 legacy = IStakingV1(LEGACY_STAKING_V1);

        uint256 legacyNextDepositId = _readLegacyNextDepositId();
        console2.log("Legacy next deposit id:", legacyNextDepositId);
        if (importLimit != type(uint256).max) {
            console2.log("Import limit applied:", importLimit);
        }

        uint256 bufferSize = legacyNextDepositId;
        if (importLimit < bufferSize) {
            bufferSize = importLimit;
        }

        StakingV2.DepositImport[] memory depositBuffer = new StakingV2.DepositImport[](bufferSize == 0 ? 1 : bufferSize);
        address[] memory tokenBuffer = new address[](bufferSize == 0 ? 1 : bufferSize);

        uint256 importCount;
        uint256 highestImportedId;
        uint256 tokenCount;

        for (uint256 depositId = 0; depositId < legacyNextDepositId; ++depositId) {
            if (importLimit != type(uint256).max && importCount >= importLimit) {
                console2.log("Reached import limit at deposit id:", depositId);
                break;
            }

            LegacyDepositRaw memory legacyDeposit = _readLegacyDeposit(legacy, depositId);

            if (legacyDeposit.staker == address(0)) {
                continue;
            }

            address targetToken = _translateTokenAddress(legacyDeposit.token);

            if (!_contains(tokenBuffer, tokenCount, legacyDeposit.token)) {
                tokenBuffer[tokenCount] = legacyDeposit.token;
                tokenCount++;
                console2.log("Discovered legacy token:", legacyDeposit.token);
            }

            depositBuffer[importCount] = _formatDepositImport(depositId, targetToken, legacyDeposit);

            importCount++;
            highestImportedId = depositId;

            if (importCount % 50 == 0) {
                console2.log("Collected checkpoint deposits:", importCount);
                console2.log("Latest processed deposit id:", depositId);
            }
        }

        StakingV2.DepositImport[] memory deposits = new StakingV2.DepositImport[](importCount);
        for (uint256 i = 0; i < importCount; ++i) {
            deposits[i] = depositBuffer[i];
        }
        snapshot.deposits = deposits;
        snapshot.highestDepositId = highestImportedId;
        snapshot.legacyNextDepositId = legacyNextDepositId;
        snapshot.totalImported = importCount;
        snapshot.nextDepositId = importCount == 0 ? legacyNextDepositId : highestImportedId + 1;

        console2.log("Total deposits collected:", importCount);

        TokenConfig[] memory tokenConfigs = new TokenConfig[](tokenCount);
        for (uint256 i = 0; i < tokenCount; ++i) {
            address legacyToken = tokenBuffer[i];
            address targetToken = _translateTokenAddress(legacyToken);
            tokenConfigs[i] = _readTokenConfig(legacy, legacyToken, targetToken);
        }
        snapshot.tokens = tokenConfigs;

        snapshot.globals = _readLegacyGlobals(legacy);

        return snapshot;
    }

    function _readLegacyNextDepositId() internal view returns (uint256) {
        // `_depositIds` lives at storage slot 1 due to AccessControlled inheritance.
        bytes32 raw = vm.load(LEGACY_STAKING_V1, bytes32(uint256(1)));
        return uint256(raw);
    }

    function _readLegacyDeposit(IStakingV1 legacy, uint256 depositId)
        internal
        view
        returns (LegacyDepositRaw memory deposit)
    {
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
        ) = legacy.userDeposits(depositId);

        if (staker == address(0)) {
            return deposit;
        }

        deposit.token = token;
        deposit.staker = staker;
        deposit.deposited = deposited;
        deposit.redeemed = redeemed;
        deposit.timeOfLastUpdate = timeOfLastUpdate;
        deposit.lastDepositTime = lastDepositTime;
        deposit.unclaimedRewards = unclaimedRewards;
        deposit.timelock = timelock;
        deposit.timelockCategory = timelockCategory;
        deposit.ratio = ratio;
        deposit.aprSnapshot = legacy.aprERC20(token);
    }

    function _formatDepositImport(
        uint256 depositId,
        address targetToken,
        LegacyDepositRaw memory legacyDeposit
    ) internal pure returns (StakingV2.DepositImport memory formatted) {
        formatted.depositId = depositId;
        formatted.token = targetToken;
        formatted.staker = legacyDeposit.staker;
        formatted.deposited = legacyDeposit.deposited;
        formatted.redeemed = legacyDeposit.redeemed;
        formatted.timeOfLastUpdate = legacyDeposit.timeOfLastUpdate;
        formatted.lastDepositTime = legacyDeposit.lastDepositTime;
        formatted.unclaimedRewards = legacyDeposit.unclaimedRewards;
        formatted.timelock = legacyDeposit.timelock;
        formatted.timelockCategory = legacyDeposit.timelockCategory;
        formatted.ratioStored = legacyDeposit.ratio;
        formatted.aprSnapshot = legacyDeposit.aprSnapshot;
    }

    function _readTokenConfig(IStakingV1 legacy, address legacyToken, address targetToken)
        internal
        view
        returns (TokenConfig memory config)
    {
        config.legacyToken = legacyToken;
        config.targetToken = targetToken;
        config.divisor = legacy.divisorERC20(legacyToken);
        config.apr = legacy.aprERC20(legacyToken);
        config.compoundFreq = legacy.compoundFreqERC20(legacyToken);
        config.withdrawalFee = legacy.withdrawalFeeERC20(legacyToken);
        config.foundersBoost = legacy.foundersRewardBoostERC20(legacyToken);
        config.knftBoost = legacy.kNFTRewardBoostERC20(legacyToken);
        config.ratio = legacy.ratioERC20(legacyToken);
        config.minStake = legacy.minStakeERC20(legacyToken);
        config.decimals = legacy.decimalsERC20(legacyToken);
        config.earlyWithdrawalPenalty = legacy.earlyWithdrawalPenalty(legacyToken);
        config.totalWithdrawalFees = legacy.totalWithdrawalFees(legacyToken);
        config.authorized = legacy.authorizedERC20(legacyToken);
    }

    function _readLegacyGlobals(IStakingV1 legacy)
        internal
        view
        returns (LegacyGlobals memory globals)
    {
        globals.helix = legacy.helixERC20();
        globals.founders = legacy.konduxERC721Founders();
        globals.knft = legacy.konduxERC721kNFT();
        globals.treasury = legacy.treasury();

        for (uint8 category = 0; category < MAX_TIMELOCK_CATEGORIES; ++category) {
            globals.timelockDurations[category] = legacy.timelockDurations(category);
            globals.timelockBoosts[category] = legacy.timelockCategoryBoost(category);
        }

        globals.dnaVersion1Allowed = legacy.allowedDnaVersions(1);
    }

    function _synchronizeGlobalConfig(StakingV2 staking, LegacyGlobals memory globals) internal {
        console2.log("Configuring global staking parameters...");

        for (uint8 category = 0; category < MAX_TIMELOCK_CATEGORIES; ++category) {
            staking.setTimelockDuration(category, globals.timelockDurations[category]);
            staking.setTimelockCategoryBoost(category, globals.timelockBoosts[category]);
            console2.log("  Timelock category", category);
            console2.log("    duration", globals.timelockDurations[category]);
            console2.log("    boost", globals.timelockBoosts[category]);
        }

        staking.setAllowedDnaVersion(1, globals.dnaVersion1Allowed);
        console2.log("  DNA version 1 allowed:", globals.dnaVersion1Allowed);
    }

    function _synchronizeTokenConfig(StakingV2 staking, TokenConfig[] memory configs) internal {
    console2.log("Configuring token set from legacy state...");
    console2.log("  token count", configs.length);

        for (uint256 i = 0; i < configs.length; ++i) {
            TokenConfig memory cfg = configs[i];
            console2.log("  Token index", i);
            console2.log("    legacy token", cfg.legacyToken);
            console2.log("    target token", cfg.targetToken);

            staking.setDivisorERC20(cfg.divisor, cfg.targetToken);
            staking.setAPR(cfg.apr, cfg.targetToken);
            staking.setCompoundFreq(cfg.compoundFreq, cfg.targetToken);
            staking.setWithdrawalFee(cfg.withdrawalFee, cfg.targetToken);
            staking.setFoundersRewardBoost(cfg.foundersBoost, cfg.targetToken);
            staking.setkNFTRewardBoost(cfg.knftBoost, cfg.targetToken);
            staking.setRatio(cfg.ratio, cfg.targetToken);
            staking.setMinStake(cfg.minStake, cfg.targetToken);
            staking.setDecimalsERC20(cfg.decimals, cfg.targetToken);
            staking.setEarlyWithdrawalPenalty(cfg.targetToken, cfg.earlyWithdrawalPenalty);
            staking.setTotalWithdrawalFees(cfg.targetToken, cfg.totalWithdrawalFees);
            staking.setAuthorizedERC20(cfg.targetToken, cfg.authorized);
        }
    }

    function _importDeposits(StakingV2 staking, LegacySnapshot memory snapshot) internal {
        if (snapshot.totalImported == 0) {
            console2.log("No deposits to import; skipping migration step.");
            return;
        }

    console2.log("Importing deposits into new staking contract...");
    console2.log("  total queued deposits", snapshot.totalImported);

        uint256 cursor;
        while (cursor < snapshot.totalImported) {
            uint256 remaining = snapshot.totalImported - cursor;
            uint256 size = remaining > DEFAULT_IMPORT_BATCH ? DEFAULT_IMPORT_BATCH : remaining;

            StakingV2.DepositImport[] memory batch = new StakingV2.DepositImport[](size);
            for (uint256 i = 0; i < size; ++i) {
                batch[i] = snapshot.deposits[cursor + i];
            }

            staking.importDeposits(batch, snapshot.nextDepositId);
            console2.log("  Imported batch starting index", cursor);
            console2.log("    batch size", size);
            console2.log("    next deposit id set", snapshot.nextDepositId);

            cursor += size;
        }
    }

    function _logSummary(
        address staking,
        AddressBook memory addresses,
        LegacySnapshot memory snapshot,
        uint256 importLimit
    ) internal view {
        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network label:", addresses.label);
        console2.log("StakingV2 address:", staking);
        console2.log("Authority:", addresses.authority);
        console2.log("Kondux token:", addresses.konduxToken);
        console2.log("Treasury:", addresses.treasury);
        console2.log("Founders pass:", addresses.foundersPass);
        console2.log("kNFT:", addresses.knft);
        console2.log("Helix:", addresses.helix);
        console2.log("Legacy next deposit id:", snapshot.legacyNextDepositId);
        console2.log("Deposits imported:", snapshot.totalImported);
        console2.log("Highest imported deposit id:", snapshot.highestDepositId);
        console2.log("Configured token count:", snapshot.tokens.length);
        if (importLimit != type(uint256).max) {
            console2.log("Import limit used:", importLimit);
        }
    }

    function _loadImportLimit() internal returns (uint256) {
        uint256 limit;
        try vm.envUint("STAKING_IMPORT_LIMIT") returns (uint256 value) {
            require(value > 0, "STAKING_IMPORT_LIMIT must be > 0");
            limit = value;
        } catch {
            limit = type(uint256).max;
        }

        if (limit == type(uint256).max) {
            console2.log("STAKING_IMPORT_LIMIT not provided; importing full legacy dataset.");
        } else {
            console2.log("STAKING_IMPORT_LIMIT set to:", limit);
        }
        return limit;
    }

    function _selectPrivateKey() internal view returns (uint256) {
        uint256 key = vm.envUint("DEPLOYER_PK");
        require(key != 0, "DEPLOYER_PK missing");
        return key;
    }

    function _resolveSepoliaAddresses() internal pure returns (AddressBook memory addresses) {
        addresses.label = "Ethereum Sepolia";
        addresses.authority = SEPOLIA_AUTHORITY;
        addresses.konduxToken = SEPOLIA_KONDUX;
        addresses.treasury = SEPOLIA_TREASURY;
        addresses.foundersPass = SEPOLIA_FOUNDERS;
        addresses.knft = SEPOLIA_KNFT;
        addresses.helix = SEPOLIA_HELIX;
        return addresses;
    }

    function _translateTokenAddress(address legacyToken) internal pure returns (address) {
        if (legacyToken == MAINNET_KONDUX) {
            return SEPOLIA_KONDUX;
        }

        revert UnknownToken(legacyToken);
    }

    function _contains(address[] memory haystack, uint256 length, address needle)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < length; ++i) {
            if (haystack[i] == needle) {
                return true;
            }
        }
        return false;
    }
}
