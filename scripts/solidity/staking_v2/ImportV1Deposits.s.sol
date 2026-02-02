// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {StakingV2} from "contracts/StakingV2.sol";
import {IStakingV1} from "contracts/interfaces/IStakingV1.sol";

/**
 * @title ImportV1Deposits
 * @notice Reads all deposits from Staking V1 and imports them into an
 *         already-deployed StakingV2 contract. Supports mainnet, Sepolia,
 *         and local (Anvil fork) networks.
 *
 * @dev Networks:
 *   Chain 1      → Ethereum Mainnet (hardcoded addresses)
 *   Chain 11155111 → Ethereum Sepolia (hardcoded addresses)
 *   Chain 31337  → Local Anvil (requires env overrides or uses mainnet defaults for fork)
 *
 * Environment Variables:
 *   REQUIRED:
 *     PROD_DEPLOYER_PK        - Private key (mainnet/local)
 *     DEPLOYER_PK             - Private key (Sepolia)
 *     STAKING_V2_ADDRESS      - Deployed V2 address (always required)
 *
 *   OPTIONAL:
 *     STAKING_V1_ADDRESS      - Override V1 address (default: per-network)
 *     KONDUX_TOKEN_ADDRESS    - Override KONDUX token (default: per-network)
 *     STAKING_IMPORT_LIMIT    - Import first N deposits only (default: all)
 *     STAKING_IMPORT_BATCH    - Deposits per batch (default: 25)
 *     FORCE_IMPORT            - Continue if V2 already has deposits (default: false)
 *
 * Usage:
 *   # Mainnet dry-run:
 *   forge script scripts/staking_v2/ImportV1Deposits.s.sol --rpc-url mainnet -vvv
 *
 *   # Mainnet broadcast:
 *   forge script scripts/staking_v2/ImportV1Deposits.s.sol --rpc-url mainnet --broadcast -vvv
 *
 *   # Sepolia:
 *   forge script scripts/staking_v2/ImportV1Deposits.s.sol --rpc-url sepolia --broadcast -vvv
 *
 *   # Local fork (reads from forked mainnet state):
 *   forge script scripts/staking_v2/ImportV1Deposits.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv
 *
 *   # Partial import (first 10 deposits):
 *   STAKING_IMPORT_LIMIT=10 forge script scripts/staking_v2/ImportV1Deposits.s.sol --rpc-url mainnet --broadcast -vvv
 */
contract ImportV1DepositsScript is Script {
    // ─── Constants ───────────────────────────────────────────────────────
    uint256 constant MAX_TIMELOCK_CATEGORIES = 4;
    uint256 constant DEFAULT_IMPORT_BATCH = 25;

    // ─── Structs ─────────────────────────────────────────────────────────

    struct NetworkConfig {
        string label;
        address stakingV1;
        address stakingV2;
        address konduxToken;
    }

    struct TokenConfig {
        address token;
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
        bool authorized;
    }

    struct LegacyGlobals {
        address helix;
        address founders;
        address knft;
        address treasury;
        uint256[4] timelockDurations;
        uint256[4] timelockBoosts;
        bool dnaVersion1Allowed;
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
        uint256 ratioERC20;
        bool active;
    }

    struct ImportStats {
        uint256 totalDeposits;
        uint256 activeDeposits;
        uint256 skippedInactive;
        uint256 skippedEmpty;
        uint256 totalImportedStake;
        uint256 totalImportedRewards;
        uint256 batchCount;
    }

    // ─── State ───────────────────────────────────────────────────────────
    IStakingV1 internal v1;
    StakingV2 internal v2;
    uint256 internal importBatch;
    uint256 internal importLimit;
    NetworkConfig internal config;

    // ─── Entry Point ─────────────────────────────────────────────────────
    function run() external {
        config = _getNetworkConfig();
        _resolveEnvConfig();

        v1 = IStakingV1(config.stakingV1);
        v2 = StakingV2(config.stakingV2);

        console2.log("=== Staking V1 -> V2 Import ===");
        console2.log("Network:", config.label);
        console2.log("Chain ID:", block.chainid);
        console2.log("V1:", config.stakingV1);
        console2.log("V2:", config.stakingV2);
        console2.log("KONDUX:", config.konduxToken);
        console2.log("Batch size:", importBatch);

        // ── Phase 1: Read V1 State ──────────────────────────────────────
        console2.log("\n--- Phase 1: Reading V1 State ---");
        uint256 nextDepositId = _readLegacyNextDepositId();
        console2.log("V1 nextDepositId:", nextDepositId);

        uint256 effectiveLimit = importLimit > 0 && importLimit < nextDepositId
            ? importLimit
            : nextDepositId;
        console2.log("Import limit:", effectiveLimit);

        // ── Phase 2: Collect active deposits ────────────────────────────
        console2.log("\n--- Phase 2: Collecting Active Deposits ---");
        (
            StakingV2.DepositImport[] memory imports,
            ImportStats memory stats
        ) = _collectDeposits(effectiveLimit);

        console2.log("Total deposits scanned:", stats.totalDeposits);
        console2.log("Active deposits to import:", stats.activeDeposits);
        console2.log("Skipped (inactive):", stats.skippedInactive);
        console2.log("Skipped (empty/zero):", stats.skippedEmpty);
        console2.log("Total stake to import:", stats.totalImportedStake);
        console2.log("Total rewards to import:", stats.totalImportedRewards);

        if (stats.activeDeposits == 0) {
            console2.log("No active deposits to import. Exiting.");
            return;
        }

        // ── Phase 3: Preflight Checks ───────────────────────────────────
        console2.log("\n--- Phase 3: Preflight Checks ---");
        _preflightChecks(nextDepositId);

        // ── Phase 4: Synchronize Global Config ──────────────────────────
        console2.log("\n--- Phase 4: Synchronizing Global Config ---");
        LegacyGlobals memory globals = _readLegacyGlobals();

        uint256 deployerPk = _selectPrivateKey();
        address deployer = vm.addr(deployerPk);
        _verifyGovernor(deployer);

        vm.startBroadcast(deployerPk);

        _synchronizeGlobalConfig(globals);

        // ── Phase 5: Synchronize Token Configs ──────────────────────────
        // NOTE: Only the KONDUX token config is synchronized. If V1 has
        // additional authorized ERC20 tokens, add them here or run a
        // separate sync step. Check V1's authorizedERC20() for each token.
        console2.log("\n--- Phase 5: Synchronizing Token Config ---");
        console2.log("WARNING: Only syncing KONDUX token config. Verify no other tokens are authorized on V1.");
        TokenConfig memory tokenCfg = _readTokenConfig(config.konduxToken);
        _synchronizeTokenConfig(tokenCfg);

        // ── Phase 6: Batch Import ───────────────────────────────────────
        console2.log("\n--- Phase 6: Importing Deposits ---");
        _importDeposits(imports, nextDepositId);

        vm.stopBroadcast();

        // ── Phase 7: Post-Import Verification ───────────────────────────
        console2.log("\n--- Phase 7: Post-Import Verification ---");
        _postImportVerification(imports, stats);

        console2.log("\n=== Import Complete ===");
    }

    // ─── Network Configuration ───────────────────────────────────────────

    function _getNetworkConfig() internal returns (NetworkConfig memory cfg) {
        // V2 is always required from env (deployed in a separate step)
        address v2Addr = _resolveEnvAddress("STAKING_V2_ADDRESS", address(0));
        require(v2Addr != address(0), "ImportV1Deposits: STAKING_V2_ADDRESS env var required");
        require(v2Addr.code.length > 0, "ImportV1Deposits: STAKING_V2_ADDRESS is not a contract");

        if (block.chainid == 1) {
            // ── Ethereum Mainnet ─────────────────────────────────────
            cfg.label = "Ethereum Mainnet";
            cfg.stakingV1 = _resolveEnvAddress(
                "STAKING_V1_ADDRESS",
                0x07E6F2239d6FbE2CE00747fCFb8344ebBf973BcC
            );
            cfg.stakingV2 = v2Addr;
            cfg.konduxToken = _resolveEnvAddress(
                "KONDUX_TOKEN_ADDRESS",
                0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1
            );
        } else if (block.chainid == 11155111) {
            // ── Ethereum Sepolia ─────────────────────────────────────
            cfg.label = "Ethereum Sepolia";
            cfg.stakingV1 = _resolveEnvAddress("STAKING_V1_ADDRESS", address(0));
            cfg.stakingV2 = v2Addr;
            cfg.konduxToken = _resolveEnvAddress(
                "KONDUX_TOKEN_ADDRESS",
                0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc
            );
            require(
                cfg.stakingV1 != address(0),
                "ImportV1Deposits: Sepolia requires STAKING_V1_ADDRESS env var"
            );
        } else if (block.chainid == 31337) {
            // ── Local Anvil (forked mainnet) ─────────────────────────
            // When running `anvil --fork-url mainnet`, chainid is 31337
            // but mainnet state is available. Use mainnet defaults unless
            // overridden by env vars.
            cfg.label = "Local Anvil (forked)";
            cfg.stakingV1 = _resolveEnvAddress(
                "STAKING_V1_ADDRESS",
                0x07E6F2239d6FbE2CE00747fCFb8344ebBf973BcC
            );
            cfg.stakingV2 = v2Addr;
            cfg.konduxToken = _resolveEnvAddress(
                "KONDUX_TOKEN_ADDRESS",
                0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1
            );
        } else {
            revert(
                string.concat(
                    "ImportV1Deposits: Unsupported chain ID ",
                    vm.toString(block.chainid),
                    ". Supported: 1 (mainnet), 11155111 (sepolia), 31337 (local)"
                )
            );
        }

        // Validate V1 is a contract (catches misconfiguration early)
        require(
            cfg.stakingV1.code.length > 0,
            "ImportV1Deposits: STAKING_V1_ADDRESS is not a contract on this network"
        );
    }

    function _resolveEnvAddress(string memory envKey, address fallback_) internal returns (address) {
        try vm.envAddress(envKey) returns (address addr) {
            if (addr != address(0)) {
                console2.log(string.concat("  [env] ", envKey, " ="), addr);
                return addr;
            }
        } catch {}
        return fallback_;
    }

    function _resolveEnvConfig() internal {
        try vm.envUint("STAKING_IMPORT_BATCH") returns (uint256 batch) {
            importBatch = batch;
        } catch {
            importBatch = DEFAULT_IMPORT_BATCH;
        }
        try vm.envUint("STAKING_IMPORT_LIMIT") returns (uint256 limit) {
            importLimit = limit;
        } catch {
            importLimit = 0; // 0 = import all
        }
    }

    function _selectPrivateKey() internal view returns (uint256) {
        // Mainnet: require PROD_DEPLOYER_PK
        if (block.chainid == 1) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        // Local Anvil: try PROD_DEPLOYER_PK, fallback to Anvil default #0
        if (block.chainid == 31337) {
            string memory pk = vm.envOr("PROD_DEPLOYER_PK", string(""));
            if (bytes(pk).length > 0) {
                return vm.envUint("PROD_DEPLOYER_PK");
            }
            return 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        // Sepolia / others: DEPLOYER_PK
        return vm.envUint("DEPLOYER_PK");
    }

    function _verifyGovernor(address deployer) internal view {
        // Verify deployer is governor on V2 before broadcasting config/import txs
        address authorityAddr = address(v2.authority());
        if (authorityAddr == address(0) || authorityAddr.code.length == 0) return;

        (bool success, bytes memory data) = authorityAddr.staticcall(
            abi.encodeWithSignature("governor()")
        );
        if (!success || data.length < 32) return;

        address governor = abi.decode(data, (address));
        if (governor != deployer) {
            console2.log("FATAL: Deployer is NOT governor on V2's Authority");
            console2.log("  Deployer:", deployer);
            console2.log("  Governor:", governor);
            // Hard revert on mainnet - waste of gas otherwise
            if (block.chainid == 1) {
                revert("ImportV1Deposits: Deployer is not governor. Fix PROD_DEPLOYER_PK.");
            }
            // Warning only on testnets (Anvil fork may impersonate)
            console2.log("  WARNING: Proceeding on testnet but txs will likely revert.");
        } else {
            console2.log("Deployer confirmed as governor:", deployer);
        }
    }

    // ─── V1 State Reading ────────────────────────────────────────────────

    function _readLegacyNextDepositId() internal view returns (uint256) {
        // _depositIds is at storage slot 1 (after AccessControlled's authority at slot 0)
        bytes32 raw = vm.load(config.stakingV1, bytes32(uint256(1)));
        return uint256(raw);
    }

    function _readLegacyDeposit(uint256 depositId) internal view returns (LegacyDepositRaw memory d) {
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
            uint256 ratioERC20
        ) = v1.userDeposits(depositId);

        d.token = token;
        d.staker = staker;
        d.deposited = deposited;
        d.redeemed = redeemed;
        d.timeOfLastUpdate = timeOfLastUpdate;
        d.lastDepositTime = lastDepositTime;
        d.unclaimedRewards = unclaimedRewards;
        d.timelock = timelock;
        d.timelockCategory = timelockCategory;
        d.ratioERC20 = ratioERC20;
        d.active = staker != address(0) && deposited > 0;
    }

    function _readTokenConfig(address token) internal view returns (TokenConfig memory cfg) {
        cfg.token = token;
        cfg.authorized = v1.authorizedERC20(token);
        cfg.minStake = v1.minStakeERC20(token);
        cfg.compoundFreq = v1.compoundFreqERC20(token);
        cfg.apr = v1.aprERC20(token);
        cfg.withdrawalFee = v1.withdrawalFeeERC20(token);
        cfg.foundersBoost = v1.foundersRewardBoostERC20(token);
        cfg.knftBoost = v1.kNFTRewardBoostERC20(token);
        cfg.ratio = v1.ratioERC20(token);
        cfg.decimals = v1.decimalsERC20(token);
        cfg.divisor = v1.divisorERC20(token);
        cfg.earlyWithdrawalPenalty = v1.earlyWithdrawalPenalty(token);
    }

    function _readLegacyGlobals() internal view returns (LegacyGlobals memory g) {
        g.helix = address(v1.helixERC20());
        g.founders = address(v1.konduxERC721Founders());
        g.knft = address(v1.konduxERC721kNFT());
        g.treasury = address(v1.treasury());

        for (uint8 i = 0; i < MAX_TIMELOCK_CATEGORIES; i++) {
            g.timelockDurations[i] = v1.timelockDurations(i);
            g.timelockBoosts[i] = v1.timelockCategoryBoost(i);
        }

        g.dnaVersion1Allowed = v1.allowedDnaVersions(1);
    }

    // ─── Deposit Collection ──────────────────────────────────────────────

    function _collectDeposits(uint256 limit)
        internal
        view
        returns (StakingV2.DepositImport[] memory, ImportStats memory)
    {
        ImportStats memory stats;
        stats.totalDeposits = limit;

        // First pass: count active deposits
        uint256 activeCount;
        for (uint256 i = 0; i < limit; i++) {
            LegacyDepositRaw memory d = _readLegacyDeposit(i);
            if (d.active) {
                activeCount++;
            }
        }

        // Second pass: collect active deposits
        StakingV2.DepositImport[] memory imports = new StakingV2.DepositImport[](activeCount);
        uint256 idx;
        for (uint256 i = 0; i < limit; i++) {
            LegacyDepositRaw memory d = _readLegacyDeposit(i);
            if (!d.active) {
                if (d.staker == address(0)) {
                    stats.skippedEmpty++;
                } else {
                    stats.skippedInactive++;
                    // Warn about unclaimed rewards that will be lost in migration
                    if (d.unclaimedRewards > 0) {
                        console2.log(
                            "WARNING: Deposit %d (staker=%s) is inactive but has unclaimed rewards: %d",
                            i,
                            d.staker,
                            d.unclaimedRewards
                        );
                    }
                }
                continue;
            }

            // Read the current APR for this token as the deposit's snapshot.
            // All V1 deposits used the global APR, so this is the correct snapshot value.
            uint256 apr = v1.aprERC20(d.token);

            imports[idx] = StakingV2.DepositImport({
                depositId: i,
                token: d.token,
                staker: d.staker,
                deposited: d.deposited,
                redeemed: d.redeemed,
                timeOfLastUpdate: d.timeOfLastUpdate,
                lastDepositTime: d.lastDepositTime,
                unclaimedRewards: d.unclaimedRewards,
                timelock: d.timelock,
                timelockCategory: d.timelockCategory,
                ratioStored: d.ratioERC20,
                aprSnapshot: apr
            });

            stats.totalImportedStake += d.deposited;
            stats.totalImportedRewards += d.redeemed;
            idx++;
        }

        stats.activeDeposits = activeCount;
        return (imports, stats);
    }

    // ─── Preflight Checks ────────────────────────────────────────────────

    function _preflightChecks(uint256 /* v1NextId */) internal view {
        // Check V2 has not already been populated (re-entrancy guard)
        uint256 v2NextId = v2.getNextDepositId();
        console2.log("V2 current nextDepositId:", v2NextId);

        if (v2NextId > 0) {
            console2.log("WARNING: V2 already has deposits. nextDepositId =", v2NextId);
            console2.log("This may be a re-run. Verify carefully before proceeding.");
            bool force = vm.envOr("FORCE_IMPORT", false);
            require(force, "ImportV1Deposits: V2 has existing deposits. Set FORCE_IMPORT=true to override.");
        }

        // Verify V2 contract is correctly linked to same dependencies
        console2.log("V2 helix:", address(v2.helixERC20()));
        console2.log("V2 founders:", address(v2.konduxERC721Founders()));
        console2.log("V2 knft:", address(v2.konduxERC721kNFT()));
        console2.log("V2 treasury:", address(v2.treasury()));

        // Verify V1 globals match what V2 should reference
        address v1Helix = address(v1.helixERC20());
        address v1Founders = address(v1.konduxERC721Founders());
        address v1Knft = address(v1.konduxERC721kNFT());
        address v1Treasury = address(v1.treasury());

        require(
            address(v2.helixERC20()) == v1Helix,
            "ImportV1Deposits: Helix mismatch between V1 and V2"
        );
        require(
            address(v2.konduxERC721Founders()) == v1Founders,
            "ImportV1Deposits: Founders NFT mismatch between V1 and V2"
        );
        require(
            address(v2.konduxERC721kNFT()) == v1Knft,
            "ImportV1Deposits: kNFT mismatch between V1 and V2"
        );
        require(
            address(v2.treasury()) == v1Treasury,
            "ImportV1Deposits: Treasury mismatch between V1 and V2"
        );

        console2.log("Preflight checks passed");
    }

    // ─── Config Synchronization ──────────────────────────────────────────

    function _synchronizeGlobalConfig(LegacyGlobals memory g) internal {
        // Timelock durations — setTimelockDuration(uint8, uint256)
        for (uint8 i = 0; i < MAX_TIMELOCK_CATEGORIES; i++) {
            uint256 currentDuration = v2.timelockDurations(i);
            if (currentDuration != g.timelockDurations[i]) {
                v2.setTimelockDuration(i, g.timelockDurations[i]);
                console2.log("Set timelockDuration[%d] = %d", uint256(i), g.timelockDurations[i]);
            }
        }

        // Timelock boosts — setTimelockCategoryBoost(uint, uint256)
        for (uint256 i = 0; i < MAX_TIMELOCK_CATEGORIES; i++) {
            uint256 currentBoost = v2.timelockCategoryBoost(i);
            if (currentBoost != g.timelockBoosts[i]) {
                v2.setTimelockCategoryBoost(i, g.timelockBoosts[i]);
                console2.log("Set timelockBoost[%d] = %d", i, g.timelockBoosts[i]);
            }
        }

        // DNA version allowlist — setAllowedDnaVersion(uint256, bool)
        bool currentDnaV1 = v2.allowedDnaVersions(1);
        if (currentDnaV1 != g.dnaVersion1Allowed) {
            v2.setAllowedDnaVersion(1, g.dnaVersion1Allowed);
            console2.log("Set allowedDnaVersions[1] =", g.dnaVersion1Allowed);
        }

        console2.log("Global config synchronized");
    }

    function _synchronizeTokenConfig(TokenConfig memory cfg) internal {
        console2.log("Syncing token config for:", cfg.token);

        // Setters with signature (address, value):
        v2.setAuthorizedERC20(cfg.token, cfg.authorized);          // setAuthorizedERC20(address, bool)
        v2.setEarlyWithdrawalPenalty(cfg.token, cfg.earlyWithdrawalPenalty); // setEarlyWithdrawalPenalty(address, uint256)

        // Setters with signature (value, address):
        v2.setAPR(cfg.apr, cfg.token);                             // setAPR(uint256, address)
        v2.setMinStake(cfg.minStake, cfg.token);                   // setMinStake(uint256, address)
        v2.setCompoundFreq(cfg.compoundFreq, cfg.token);           // setCompoundFreq(uint256, address)
        v2.setWithdrawalFee(cfg.withdrawalFee, cfg.token);         // setWithdrawalFee(uint256, address)
        v2.setFoundersRewardBoost(cfg.foundersBoost, cfg.token);   // setFoundersRewardBoost(uint256, address)
        v2.setkNFTRewardBoost(cfg.knftBoost, cfg.token);           // setkNFTRewardBoost(uint256, address)
        v2.setRatio(cfg.ratio, cfg.token);                         // setRatio(uint256, address)
        v2.setDivisorERC20(cfg.divisor, cfg.token);                // setDivisorERC20(uint256, address)
        v2.setDecimalsERC20(cfg.decimals, cfg.token);              // setDecimalsERC20(uint8, address)

        console2.log("  APR:", cfg.apr);
        console2.log("  Ratio:", cfg.ratio);
        console2.log("  MinStake:", cfg.minStake);
        console2.log("  WithdrawalFee:", cfg.withdrawalFee);
        console2.log("  CompoundFreq:", cfg.compoundFreq);
        console2.log("  Authorized:", cfg.authorized);
    }

    // ─── Deposit Import ──────────────────────────────────────────────────

    function _importDeposits(
        StakingV2.DepositImport[] memory imports,
        uint256 nextDepositId
    ) internal {
        uint256 total = imports.length;
        uint256 batchStart = 0;

        while (batchStart < total) {
            uint256 batchEnd = batchStart + importBatch;
            if (batchEnd > total) batchEnd = total;

            uint256 batchSize = batchEnd - batchStart;
            StakingV2.DepositImport[] memory batch = new StakingV2.DepositImport[](batchSize);
            for (uint256 i = 0; i < batchSize; i++) {
                batch[i] = imports[batchStart + i];
            }

            // Only set nextDepositId on the final batch
            uint256 batchNextId = (batchEnd == total) ? nextDepositId : 0;

            console2.log("Importing batch %d..%d of %d", batchStart, batchEnd - 1, total);
            if (batchNextId > 0) console2.log("  Setting nextDepositId:", batchNextId);

            v2.importDeposits(batch, batchNextId);

            batchStart = batchEnd;
        }

        console2.log("All deposits imported successfully");
    }

    // ─── Post-Import Verification ────────────────────────────────────────

    function _postImportVerification(
        StakingV2.DepositImport[] memory imports,
        ImportStats memory stats
    ) internal view {
        // Verify nextDepositId was set correctly
        uint256 v1NextId = _readLegacyNextDepositId();
        uint256 v2NextId = v2.getNextDepositId();
        console2.log("V1 nextDepositId:", v1NextId);
        console2.log("V2 nextDepositId:", v2NextId);
        require(v2NextId == v1NextId, "ImportV1Deposits: nextDepositId mismatch after import");

        // Spot-check deposits: first 3 + last 2 (catches batch boundary bugs)
        uint256 total = imports.length;
        uint256 headCount = total < 3 ? total : 3;
        uint256 tailCount = total <= 3 ? 0 : (total < 5 ? total - 3 : 2);

        for (uint256 i = 0; i < headCount; i++) {
            _verifyDeposit(imports[i]);
        }
        for (uint256 i = 0; i < tailCount; i++) {
            _verifyDeposit(imports[total - tailCount + i]);
        }

        // Verify aggregate totals
        uint256 v1Total = v1.totalStaked(config.konduxToken);
        uint256 v2Total = v2.totalStaked(config.konduxToken);
        console2.log("V1 totalStaked:", v1Total);
        console2.log("V2 totalStaked:", v2Total);

        require(
            v2Total >= stats.totalImportedStake,
            "ImportV1Deposits: V2 totalStaked less than imported amount"
        );

        // TOCTOU drift warning: V1 state may have changed between snapshot and import
        if (v1Total > v2Total) {
            uint256 drift = v1Total - v2Total;
            console2.log("WARNING: V1 totalStaked > V2 totalStaked by %d wei", drift);
            console2.log("This indicates deposits occurred on V1 AFTER the import snapshot.");
            console2.log("Execute ShutdownStakingV1 immediately to close this window.");
        }

        console2.log("Post-import verification PASSED");
    }

    function _verifyDeposit(StakingV2.DepositImport memory expected) internal view {
        (
            address token,
            address staker,
            uint256 deposited,
            , // redeemed
            , // timeOfLastUpdate
            , // lastDepositTime
            , // unclaimedRewards
            , // timelock
            , // timelockCategory
              // ratioERC20
        ) = v2.userDeposits(expected.depositId);

        require(token == expected.token, "Deposit token mismatch");
        require(staker == expected.staker, "Deposit staker mismatch");
        require(deposited == expected.deposited, "Deposit amount mismatch");

        // Verify APR snapshot (returns tuple: snapshot, exists)
        (uint256 snapshot, bool exists) = v2.getDepositAprSnapshot(expected.depositId);
        require(exists, "APR snapshot not set for imported deposit");
        require(snapshot == expected.aprSnapshot, "APR snapshot mismatch");

        console2.log("Verified deposit %d: staker=%s", expected.depositId, expected.staker);
        console2.log("  deposited=%d apr=%d", expected.deposited, snapshot);
    }
}
