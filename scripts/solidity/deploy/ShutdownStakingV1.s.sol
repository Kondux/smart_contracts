// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {Staking} from "contracts/Staking.sol";
import {StakingV2} from "contracts/StakingV2.sol";
import {Helix} from "contracts/Helix.sol";
import {IAuthority} from "contracts/interfaces/IAuthority.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ShutdownStakingV1Script
 * @notice Shuts down StakingV1 and enables StakingV2 for migration
 * @dev This script performs the following actions:
 *      1. Deauthorizes KONDUX token in V1 (prevents new deposits)
 *      2. Revokes V1's MINTER_ROLE from Helix (prevents restaking)
 *      3. Revokes V1's BURNER_ROLE from Helix (prevents withdrawals)
 *      4. Grants V2's MINTER_ROLE to Helix (enables deposits/restaking)
 *      5. Grants V2's BURNER_ROLE to Helix (enables withdrawals)
 * 
 * CRITICAL: This forces all users to use V2 for withdrawals.
 *           Ensure all V1 deposits are imported to V2 BEFORE running this script!
 * 
 * PREREQUISITES:
 *   - StakingV2 must be deployed
 *   - All V1 deposits must be imported to V2 via importDeposits()
 *   - Treasury must have approved V2 for token transfers
 *   - Deployer must have Governor role on StakingV1 AND Admin role on Helix
 *     (or run as separate transactions from different signers)
 * 
 * ENVIRONMENT VARIABLES:
 *   - PROD_DEPLOYER_PK: Private key for mainnet execution
 *   - FORCE_SHUTDOWN: Set to "true" to proceed even if V1 has unimported deposits
 *   - SKIP_TREASURY_CHECK: Set to "true" to skip Treasury approval verification
 */
contract ShutdownStakingV1Script is Script {
    // Role hashes - will be verified against contract at runtime
    bytes32 internal constant EXPECTED_MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant EXPECTED_BURNER_ROLE = keccak256("BURNER_ROLE");

    // Errors
    error V1HasUnimportedDeposits(uint256 v1Staked, uint256 v2Staked);
    error TreasuryNotApprovedV2(uint256 currentAllowance);
    error RoleHashMismatch(string role, bytes32 expected, bytes32 actual);
    error V1NotFullyShutdown();
    error V2NotFullyEnabled();
    error V2NotInHelixAllowlist();
    error MissingPermissions(string context);

    struct NetworkConfig {
        string label;
        address stakingV1;
        address stakingV2;
        address helix;
        address konduxToken;
        address authority;
    }

    struct PreflightStatus {
        bool v1Authorized;
        bool v1HasMinter;
        bool v1HasBurner;
        bool v2HasMinter;
        bool v2HasBurner;
        bool v2InAllowlist;
        uint256 v1TotalStaked;
        uint256 v2TotalStaked;
        uint256 treasuryAllowanceV2;
        address vault;
    }

    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== StakingV1 Shutdown Script ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        console2.log("");

        NetworkConfig memory config = _getNetworkConfig();
        _validateConfig(config);

        console2.log("Network:", config.label);
        console2.log("StakingV1:", config.stakingV1);
        console2.log("StakingV2:", config.stakingV2);
        console2.log("Helix:", config.helix);
        console2.log("Kondux Token:", config.konduxToken);
        console2.log("Authority:", config.authority);
        console2.log("");

        // Comprehensive safety checks before shutdown
        PreflightStatus memory status = _performSafetyChecks(config, deployer);

        // Critical verifications that can block execution
        _performCriticalVerifications(config, status);

        console2.log("=== ALL CHECKS PASSED - EXECUTING SHUTDOWN ===");
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Phase 1: Shutdown V1
        _shutdownStakingV1(config);

        // Phase 2: Enable V2 (with ordering protection)
        _enableStakingV2(config);

        vm.stopBroadcast();

        // Phase 3: Verify shutdown (read-only, after broadcast)
        _verifyShutdown(config);

        console2.log("");
        console2.log("=== SHUTDOWN COMPLETE ===");
        _logFinalStatus(config);
    }

    function _getNetworkConfig() internal view returns (NetworkConfig memory) {
        if (block.chainid == 1) {
            // Ethereum Mainnet
            return NetworkConfig({
                label: "Ethereum Mainnet",
                stakingV1: 0x07E6F2239d6FbE2CE00747fCFb8344ebBf973BcC,
                stakingV2: address(0), // TODO: Update after V2 deployment
                helix: 0x69a4A1CD8F2f2c3500F64634B9d69C642e9A5CA4,
                konduxToken: 0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1,
                authority: 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A
            });
        }

        if (block.chainid == 11155111) {
            // Ethereum Sepolia
            return NetworkConfig({
                label: "Ethereum Sepolia",
                stakingV1: address(0), // TODO: Update if V1 exists on Sepolia
                stakingV2: address(0), // TODO: Update after V2 deployment
                helix: 0xb94F89750d9889656a6D081A0F06cBd3FA3Ad04B,
                konduxToken: 0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc,
                authority: 0x685a13093cA561F531c93185B942a3f33385e14E
            });
        }

        if (block.chainid == 31337) {
            // Local Anvil - for testing
            revert("Local testing not configured. Deploy contracts first.");
        }

        revert("Unsupported network");
    }

    function _validateConfig(NetworkConfig memory config) internal pure {
        require(config.stakingV1 != address(0), "StakingV1 address not set");
        require(config.stakingV2 != address(0), "StakingV2 address not set - deploy V2 first");
        require(config.helix != address(0), "Helix address not set");
        require(config.konduxToken != address(0), "Kondux token address not set");
        require(config.authority != address(0), "Authority address not set");
    }

    function _performSafetyChecks(
        NetworkConfig memory config,
        address deployer
    ) internal view returns (PreflightStatus memory status) {
        Staking stakingV1 = Staking(config.stakingV1);
        StakingV2 stakingV2 = StakingV2(config.stakingV2);
        Helix helix = Helix(config.helix);
        IERC20 konduxToken = IERC20(config.konduxToken);
        IAuthority authority = IAuthority(config.authority);

        console2.log("=== PRE-SHUTDOWN SAFETY CHECKS ===");
        console2.log("");

        // Get vault address
        status.vault = authority.vault();
        console2.log("Treasury/Vault:", status.vault);
        console2.log("");

        // Check V1 authorization status
        status.v1Authorized = stakingV1.authorizedERC20(config.konduxToken);
        console2.log("V1 Token Authorized:", status.v1Authorized);

        // Check V1 roles
        status.v1HasMinter = helix.hasRole(EXPECTED_MINTER_ROLE, config.stakingV1);
        status.v1HasBurner = helix.hasRole(EXPECTED_BURNER_ROLE, config.stakingV1);
        console2.log("V1 Has MINTER_ROLE:", status.v1HasMinter);
        console2.log("V1 Has BURNER_ROLE:", status.v1HasBurner);

        // Check V2 roles (should be false before shutdown)
        status.v2HasMinter = helix.hasRole(EXPECTED_MINTER_ROLE, config.stakingV2);
        status.v2HasBurner = helix.hasRole(EXPECTED_BURNER_ROLE, config.stakingV2);
        console2.log("V2 Has MINTER_ROLE:", status.v2HasMinter);
        console2.log("V2 Has BURNER_ROLE:", status.v2HasBurner);

        // Check V2 in Helix allowlist (for transfers)
        status.v2InAllowlist = helix.allowedContracts(config.stakingV2);
        console2.log("V2 In Helix Allowlist:", status.v2InAllowlist);
        console2.log("");

        // Check TVL in both contracts
        status.v1TotalStaked = stakingV1.totalStaked(config.konduxToken);
        status.v2TotalStaked = stakingV2.totalStaked(config.konduxToken);
        console2.log("V1 Total Staked (wei):", status.v1TotalStaked);
        console2.log("V1 Total Staked (KONDUX):", status.v1TotalStaked / 1e18);
        console2.log("V2 Total Staked (wei):", status.v2TotalStaked);
        console2.log("V2 Total Staked (KONDUX):", status.v2TotalStaked / 1e18);
        console2.log("");

        // Check Treasury approval for V2
        status.treasuryAllowanceV2 = konduxToken.allowance(status.vault, config.stakingV2);
        console2.log("Treasury->V2 Allowance:", status.treasuryAllowanceV2);
        if (status.treasuryAllowanceV2 == type(uint256).max) {
            console2.log("Treasury->V2 Allowance: UNLIMITED");
        }
        console2.log("");

        // Check deployer permissions
        console2.log("=== PERMISSION CHECKS ===");
        // Note: We can't easily check governor role without knowing the exact access control mechanism
        // The script will revert on execution if permissions are missing
        console2.log("Deployer:", deployer);
        console2.log("(Permissions will be verified during execution)");
        console2.log("");

        // Log warnings
        console2.log("=== WARNINGS ===");
        
        if (status.v1TotalStaked > 0 && status.v2TotalStaked < status.v1TotalStaked) {
            console2.log("[CRITICAL] V1 has deposits that may not be imported to V2!");
            console2.log("  V1 Staked:", status.v1TotalStaked / 1e18, "KONDUX");
            console2.log("  V2 Staked:", status.v2TotalStaked / 1e18, "KONDUX");
        }
        
        if (!status.v1HasMinter || !status.v1HasBurner) {
            console2.log("[WARNING] V1 already partially shutdown!");
        }
        
        if (status.v2HasMinter || status.v2HasBurner) {
            console2.log("[WARNING] V2 already has roles granted!");
        }
        
        if (!status.v2InAllowlist) {
            console2.log("[WARNING] V2 not in Helix allowedContracts - Helix transfers may be restricted");
        }
        
        if (status.treasuryAllowanceV2 == 0) {
            console2.log("[CRITICAL] Treasury has NOT approved V2 - withdrawals will fail!");
        }
        
        console2.log("");

        return status;
    }

    function _performCriticalVerifications(
        NetworkConfig memory config,
        PreflightStatus memory status
    ) internal view {
        Helix helix = Helix(config.helix);

        console2.log("=== CRITICAL VERIFICATIONS ===");
        console2.log("");

        // 1. Verify role hashes match what Helix expects
        bytes32 actualMinterRole = helix.MINTER_ROLE();
        bytes32 actualBurnerRole = helix.BURNER_ROLE();
        
        if (actualMinterRole != EXPECTED_MINTER_ROLE) {
            revert RoleHashMismatch("MINTER_ROLE", EXPECTED_MINTER_ROLE, actualMinterRole);
        }
        console2.log("[OK] MINTER_ROLE hash verified");
        
        if (actualBurnerRole != EXPECTED_BURNER_ROLE) {
            revert RoleHashMismatch("BURNER_ROLE", EXPECTED_BURNER_ROLE, actualBurnerRole);
        }
        console2.log("[OK] BURNER_ROLE hash verified");

        // 2. Verify V2 deposits >= V1 deposits (critical for user funds safety)
        if (status.v1TotalStaked > 0) {
            bool forceShutdown = vm.envOr("FORCE_SHUTDOWN", false);
            
            if (status.v2TotalStaked < status.v1TotalStaked) {
                if (!forceShutdown) {
                    console2.log("");
                    console2.log("[BLOCKED] V1 has deposits that are not in V2!");
                    console2.log("  To proceed anyway, set FORCE_SHUTDOWN=true");
                    console2.log("  This is DANGEROUS - users may lose access to funds!");
                    revert V1HasUnimportedDeposits(status.v1TotalStaked, status.v2TotalStaked);
                }
                console2.log("[OVERRIDE] FORCE_SHUTDOWN=true - proceeding despite deposit mismatch");
            } else {
                console2.log("[OK] V2 has imported all V1 deposits");
            }
        } else {
            console2.log("[OK] V1 has no staked deposits");
        }

        // 3. Verify Treasury has approved V2 for withdrawals
        bool skipTreasuryCheck = vm.envOr("SKIP_TREASURY_CHECK", false);
        
        if (status.treasuryAllowanceV2 == 0) {
            if (!skipTreasuryCheck) {
                console2.log("");
                console2.log("[BLOCKED] Treasury has not approved V2!");
                console2.log("  To proceed anyway, set SKIP_TREASURY_CHECK=true");
                console2.log("  WARNING: Withdrawals will fail until Treasury approves V2!");
                revert TreasuryNotApprovedV2(status.treasuryAllowanceV2);
            }
            console2.log("[OVERRIDE] SKIP_TREASURY_CHECK=true - proceeding without Treasury approval");
        } else {
            console2.log("[OK] Treasury has approved V2 for transfers");
        }

        // 4. Warn about Helix allowlist (non-blocking)
        if (!status.v2InAllowlist) {
            console2.log("[WARN] V2 not in Helix allowlist - ensure this is intentional");
        } else {
            console2.log("[OK] V2 is in Helix allowlist");
        }

        console2.log("");
    }

    function _shutdownStakingV1(NetworkConfig memory config) internal {
        console2.log("Phase 1: Shutting down StakingV1...");
        
        Staking stakingV1 = Staking(config.stakingV1);
        Helix helix = Helix(config.helix);

        // Step 1: Deauthorize token (prevents new deposits)
        console2.log("  [1/3] Deauthorizing KONDUX token in V1...");
        try stakingV1.setAuthorizedERC20(config.konduxToken, false) {
            console2.log("  [OK] Token deauthorized");
        } catch Error(string memory reason) {
            console2.log("  [FAILED] Token deauthorization failed:", reason);
            revert MissingPermissions("Governor role required for setAuthorizedERC20");
        }

        // Step 2: Revoke MINTER_ROLE (prevents restaking)
        console2.log("  [2/3] Revoking V1 MINTER_ROLE...");
        try helix.setRole(EXPECTED_MINTER_ROLE, config.stakingV1, false) {
            console2.log("  [OK] MINTER_ROLE revoked");
        } catch Error(string memory reason) {
            console2.log("  [FAILED] MINTER_ROLE revocation failed:", reason);
            revert MissingPermissions("Admin role required on Helix for setRole");
        }

        // Step 3: Revoke BURNER_ROLE (prevents withdrawals - CRITICAL!)
        console2.log("  [3/3] Revoking V1 BURNER_ROLE...");
        try helix.setRole(EXPECTED_BURNER_ROLE, config.stakingV1, false) {
            console2.log("  [OK] BURNER_ROLE revoked");
        } catch Error(string memory reason) {
            console2.log("  [FAILED] BURNER_ROLE revocation failed:", reason);
            revert MissingPermissions("Admin role required on Helix for setRole");
        }

        console2.log("[OK] Phase 1 Complete: V1 fully shutdown");
        console2.log("");
    }

    function _enableStakingV2(NetworkConfig memory config) internal {
        console2.log("Phase 2: Enabling StakingV2...");
        
        Staking stakingV1 = Staking(config.stakingV1);
        Helix helix = Helix(config.helix);

        // ORDERING PROTECTION: Verify V1 is fully shutdown before enabling V2
        // This prevents race conditions where both contracts could be active
        console2.log("  [0/2] Verifying V1 shutdown before enabling V2...");
        
        bool v1StillAuthorized = stakingV1.authorizedERC20(config.konduxToken);
        bool v1StillHasMinter = helix.hasRole(EXPECTED_MINTER_ROLE, config.stakingV1);
        bool v1StillHasBurner = helix.hasRole(EXPECTED_BURNER_ROLE, config.stakingV1);
        
        if (v1StillAuthorized || v1StillHasMinter || v1StillHasBurner) {
            console2.log("  [FAILED] V1 not fully shutdown!");
            console2.log("    V1 Authorized:", v1StillAuthorized);
            console2.log("    V1 Has MINTER:", v1StillHasMinter);
            console2.log("    V1 Has BURNER:", v1StillHasBurner);
            revert V1NotFullyShutdown();
        }
        console2.log("  [OK] V1 confirmed shutdown");

        // Step 1: Grant MINTER_ROLE (enables deposits/restaking)
        console2.log("  [1/2] Granting V2 MINTER_ROLE...");
        try helix.setRole(EXPECTED_MINTER_ROLE, config.stakingV2, true) {
            console2.log("  [OK] MINTER_ROLE granted");
        } catch Error(string memory reason) {
            console2.log("  [FAILED] MINTER_ROLE grant failed:", reason);
            revert MissingPermissions("Admin role required on Helix for setRole");
        }

        // Step 2: Grant BURNER_ROLE (enables withdrawals)
        console2.log("  [2/2] Granting V2 BURNER_ROLE...");
        try helix.setRole(EXPECTED_BURNER_ROLE, config.stakingV2, true) {
            console2.log("  [OK] BURNER_ROLE granted");
        } catch Error(string memory reason) {
            console2.log("  [FAILED] BURNER_ROLE grant failed:", reason);
            revert MissingPermissions("Admin role required on Helix for setRole");
        }

        console2.log("[OK] Phase 2 Complete: V2 fully enabled");
        console2.log("");
    }

    function _verifyShutdown(NetworkConfig memory config) internal view {
        console2.log("Phase 3: Verifying shutdown...");
        
        Staking stakingV1 = Staking(config.stakingV1);
        Helix helix = Helix(config.helix);

        // Verify V1 shutdown
        bool v1Authorized = stakingV1.authorizedERC20(config.konduxToken);
        bool v1HasMinter = helix.hasRole(EXPECTED_MINTER_ROLE, config.stakingV1);
        bool v1HasBurner = helix.hasRole(EXPECTED_BURNER_ROLE, config.stakingV1);

        if (v1Authorized || v1HasMinter || v1HasBurner) {
            console2.log("  [FAILED] V1 verification failed!");
            console2.log("    V1 Authorized:", v1Authorized);
            console2.log("    V1 Has MINTER:", v1HasMinter);
            console2.log("    V1 Has BURNER:", v1HasBurner);
            revert V1NotFullyShutdown();
        }
        console2.log("  [OK] V1 fully shutdown");

        // Verify V2 enabled
        bool v2HasMinter = helix.hasRole(EXPECTED_MINTER_ROLE, config.stakingV2);
        bool v2HasBurner = helix.hasRole(EXPECTED_BURNER_ROLE, config.stakingV2);

        if (!v2HasMinter || !v2HasBurner) {
            console2.log("  [FAILED] V2 verification failed!");
            console2.log("    V2 Has MINTER:", v2HasMinter);
            console2.log("    V2 Has BURNER:", v2HasBurner);
            revert V2NotFullyEnabled();
        }
        console2.log("  [OK] V2 fully enabled");

        console2.log("[OK] Phase 3 Complete: Verification passed");
        console2.log("");
    }

    function _logFinalStatus(NetworkConfig memory config) internal view {
        Staking stakingV1 = Staking(config.stakingV1);
        StakingV2 stakingV2 = StakingV2(config.stakingV2);
        Helix helix = Helix(config.helix);

        console2.log("Final Status:");
        console2.log("-------------");
        console2.log("");
        
        console2.log("StakingV1 (DISABLED):");
        console2.log("  Address:", config.stakingV1);
        console2.log("  Token Authorized:", stakingV1.authorizedERC20(config.konduxToken));
        console2.log("  MINTER_ROLE:", helix.hasRole(EXPECTED_MINTER_ROLE, config.stakingV1));
        console2.log("  BURNER_ROLE:", helix.hasRole(EXPECTED_BURNER_ROLE, config.stakingV1));
        console2.log("");
        
        console2.log("StakingV2 (ENABLED):");
        console2.log("  Address:", config.stakingV2);
        console2.log("  Token Authorized:", stakingV2.authorizedERC20(config.konduxToken));
        console2.log("  MINTER_ROLE:", helix.hasRole(EXPECTED_MINTER_ROLE, config.stakingV2));
        console2.log("  BURNER_ROLE:", helix.hasRole(EXPECTED_BURNER_ROLE, config.stakingV2));
        console2.log("  Total Staked:", stakingV2.totalStaked(config.konduxToken) / 1e18, "KONDUX");
        console2.log("");
        
        console2.log("=== NEXT STEPS ===");
        console2.log("1. Verify on Etherscan that all transactions succeeded");
        console2.log("2. Announce migration to users");
        console2.log("3. Update frontend to point to V2:", config.stakingV2);
        console2.log("4. Monitor V1 for any unexpected activity (should be zero)");
        console2.log("5. Users can now withdraw from V2 using same deposit IDs");
        console2.log("");
        console2.log("=== EMERGENCY ROLLBACK ===");
        console2.log("If issues arise, re-enable V1 by running:");
        console2.log("  stakingV1.setAuthorizedERC20(KONDUX_TOKEN, true)");
        console2.log("  helix.setRole(MINTER_ROLE, STAKING_V1, true)");
        console2.log("  helix.setRole(BURNER_ROLE, STAKING_V1, true)");
    }

    function _selectPrivateKey() internal view returns (uint256) {
        // Try production deployer key first
        string memory prodKey = vm.envOr("PROD_DEPLOYER_PK", string(""));
        if (bytes(prodKey).length > 0) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }

        // Fallback to default for local testing
        if (block.chainid == 31337) {
            // Anvil default key #0
            return 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }

        revert("PROD_DEPLOYER_PK not set in environment");
    }
}
