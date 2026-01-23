// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {ICreatorTokenTransferValidator} from "contracts/interfaces/ICreatorTokenTransferValidator.sol";

/**
 * @title MigrateToValidatorV3
 * @notice Migrates a collection from the old transfer validator to the new v3 validator
 * @dev This script:
 *      1. Switches the collection's transfer validator to v3
 *      2. Creates a new whitelist with OpenSea conduit + Seaport addresses
 *      3. Applies the whitelist with security level 4 (Operator Whitelist, OTC disabled)
 *
 *      The v3 validator (0x721C0078c2328597Ca70F5451ffF5A7B38D4E947) already has OpenSea's
 *      SignedZone configured as a global authorizer, which is required for Seaport Hooks
 *      to enforce royalties.
 *
 * Usage:
 *   # Dry run (read-only check)
 *   forge script scripts/solidity/utility/MigrateToValidatorV3.s.sol:CheckValidatorMigrationScript \
 *       --rpc-url mainnet -vvv
 *
 *   # Apply migration
 *   forge script scripts/solidity/utility/MigrateToValidatorV3.s.sol \
 *       --rpc-url mainnet --broadcast -vvv
 *
 * Environment variables:
 *   PROD_DEPLOYER_PK - Admin private key (required for broadcast)
 *   TARGET_COLLECTION - (Optional) Override target collection address
 */
contract MigrateToValidatorV3Script is Script {
    // Default target - Kondux Omniforge mainnet
    address public constant DEFAULT_TARGET = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;

    // ============ Transfer Validators ============
    // Old validator (v1/v2) - does NOT have OpenSea SignedZone as authorizer
    address public constant OLD_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    
    // New validator (v3) - has OpenSea SignedZone configured for Seaport Hooks
    address public constant NEW_VALIDATOR_V3 = 0x721C0078c2328597Ca70F5451ffF5A7B38D4E947;

    // ============ OpenSea / Seaport Addresses ============
    address public constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address public constant SEAPORT_16 = 0x0000000000000068F116a894984e2DB1123eB395;
    address public constant SEAPORT_15 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address public constant SEAPORT_14 = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address public constant SEAPORT_11 = 0x00000000006c3852cbEf3e08E8dF289169EdE581;

    // OpenSea's SignedZone - must be authorizer for Seaport Hooks royalty enforcement
    address public constant OPENSEA_SIGNED_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;

    // List type constants
    uint8 public constant LIST_TYPE_WHITELIST = 1;
    uint8 public constant LIST_TYPE_AUTHORIZERS = 2;

    // Ruleset 4 = Operator Whitelist with OTC disabled
    uint8 public constant RULESET_OPERATOR_WHITELIST = 4;

    function run() external {
        address target = vm.envOr("TARGET_COLLECTION", DEFAULT_TARGET);

        console2.log("=== Migrate to Validator V3 Script ===");
        console2.log("");
        console2.log("Target collection:", target);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        KonduxImplementation kondux = KonduxImplementation(payable(target));

        // Check current state
        address currentValidator = kondux.getTransferValidator();
        console2.log("--- Current State ---");
        console2.log("Current Validator:", currentValidator);
        
        if (currentValidator == NEW_VALIDATOR_V3) {
            console2.log("");
            console2.log("[OK] Collection is already using the v3 validator!");
            console2.log("No migration needed.");
            return;
        }

        if (currentValidator == OLD_VALIDATOR) {
            console2.log("Validator Version: v1/v2 (OLD - needs migration)");
        } else if (currentValidator == address(0)) {
            console2.log("Validator Version: None set");
        } else {
            console2.log("Validator Version: Unknown");
        }

        // Verify we have admin access
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("");
        console2.log("Deployer:", deployer);

        bytes32 adminRole = kondux.DEFAULT_ADMIN_ROLE();
        bool isAdmin = kondux.hasRole(adminRole, deployer);

        if (!isAdmin) {
            console2.log("");
            console2.log("[ERROR] Deployer is NOT an admin of the collection!");
            revert("Deployer is not admin");
        }
        console2.log("Deployer has admin role: YES");

        // Start migration
        console2.log("");
        console2.log("=== Starting Migration to V3 Validator ===");

        vm.startBroadcast(deployerKey);

        // Step 1: Switch to the new v3 validator
        console2.log("");
        console2.log("Step 1: Switching to v3 validator...");
        console2.log("  Old validator:", currentValidator);
        console2.log("  New validator:", NEW_VALIDATOR_V3);
        
        kondux.setTransferValidator(NEW_VALIDATOR_V3);
        console2.log("  -> Validator switched!");

        // Step 2: Set up security policy on the new validator
        // The collection needs to call setToDefaultSecurityPolicy() to create a whitelist
        console2.log("");
        console2.log("Step 2: Setting up security policy on v3 validator...");
        
        // Use the built-in function which creates whitelist with Seaport 1.6
        kondux.setToDefaultSecurityPolicy();
        console2.log("  -> Default security policy set (whitelist with Seaport 1.6)");

        // Step 3: Add OpenSea conduit and additional Seaport versions to whitelist
        console2.log("");
        console2.log("Step 3: Adding OpenSea conduit and Seaport versions to whitelist...");
        
        address[] memory operatorsToAdd = new address[](4);
        operatorsToAdd[0] = OPENSEA_CONDUIT;
        operatorsToAdd[1] = SEAPORT_15;
        operatorsToAdd[2] = SEAPORT_14;
        operatorsToAdd[3] = SEAPORT_11;

        kondux.addAccountsToWhitelist(operatorsToAdd);
        console2.log("  -> Added OpenSea Conduit:", OPENSEA_CONDUIT);
        console2.log("  -> Added Seaport 1.5:", SEAPORT_15);
        console2.log("  -> Added Seaport 1.4:", SEAPORT_14);
        console2.log("  -> Added Seaport 1.1:", SEAPORT_11);

        vm.stopBroadcast();

        // Verify final state
        console2.log("");
        console2.log("=== Post-Migration Verification ===");

        address newValidator = kondux.getTransferValidator();
        console2.log("New Validator:", newValidator);
        console2.log("Is V3:", newValidator == NEW_VALIDATOR_V3 ? "YES" : "NO");

        (bytes4 selector, bool isEnabled) = kondux.getTransferValidationFunction();
        console2.log("Validation Function:");
        console2.log("  Selector:", vm.toString(selector));
        console2.log("  Enabled:", isEnabled ? "YES" : "NO");

        console2.log("");
        console2.log("=== SUCCESS ===");
        console2.log("Collection has been migrated to the v3 transfer validator.");
        console2.log("");
        console2.log("What this means:");
        console2.log("  - The v3 validator has OpenSea's SignedZone as a global authorizer");
        console2.log("  - Seaport Hooks will now enforce royalties on OpenSea");
        console2.log("  - Buyers can no longer skip royalties on OpenSea");
        console2.log("");
        console2.log("NOTE: It may take some time for OpenSea to reflect the changes.");
        console2.log("      Clear cache and refresh the collection page if needed.");
    }
}

/**
 * @title CheckValidatorMigrationScript
 * @notice Read-only script to check current validator status and migration needs
 */
contract CheckValidatorMigrationScript is Script {
    address public constant DEFAULT_TARGET = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;
    address public constant OLD_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    address public constant NEW_VALIDATOR_V3 = 0x721C0078c2328597Ca70F5451ffF5A7B38D4E947;
    address public constant OPENSEA_SIGNED_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;

    uint8 public constant LIST_TYPE_AUTHORIZERS = 2;

    function run() external view {
        address target = vm.envOr("TARGET_COLLECTION", DEFAULT_TARGET);

        console2.log("=== Validator Migration Check (Read-Only) ===");
        console2.log("");
        console2.log("Target collection:", target);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        KonduxImplementation kondux = KonduxImplementation(payable(target));
        address currentValidator = kondux.getTransferValidator();

        console2.log("--- Transfer Validator ---");
        console2.log("Current Validator:", currentValidator);

        if (currentValidator == NEW_VALIDATOR_V3) {
            console2.log("Version: V3 (LATEST)");
            console2.log("");
            console2.log("[OK] Collection is using the latest v3 validator.");
            console2.log("OpenSea Seaport Hooks should enforce royalties.");
        } else if (currentValidator == OLD_VALIDATOR) {
            console2.log("Version: V1/V2 (OLD)");
            console2.log("");
            console2.log("[!] Collection is using the OLD validator!");
            console2.log("");
            console2.log("The old validator does NOT have OpenSea's SignedZone as an authorizer.");
            console2.log("This is why OpenSea allows buyers to skip royalties.");
            console2.log("");
            console2.log("To fix, run the migration script:");
            console2.log("  forge script scripts/solidity/utility/MigrateToValidatorV3.s.sol \\");
            console2.log("      --rpc-url mainnet --broadcast -vvv");
        } else if (currentValidator == address(0)) {
            console2.log("Version: None");
            console2.log("");
            console2.log("[!] No transfer validator is set!");
            console2.log("The collection has no transfer restrictions.");
        } else {
            console2.log("Version: Unknown");
            console2.log("");
            console2.log("[?] Unknown validator address.");
        }

        // Check validation function
        console2.log("");
        console2.log("--- Transfer Validation Function ---");
        (bytes4 selector, bool isEnabled) = kondux.getTransferValidationFunction();
        console2.log("Selector:", vm.toString(selector));
        console2.log("Enabled:", isEnabled ? "YES" : "NO");

        if (selector == bytes4(0xcaee23ea) && isEnabled) {
            console2.log("Status: Correctly configured");
        } else {
            console2.log("Status: May need configuration");
        }

        // Check royalty info
        console2.log("");
        console2.log("--- Royalty Info ---");
        try kondux.royaltyInfo(0, 10000) returns (address receiver, uint256 amount) {
            console2.log("Receiver:", receiver);
            console2.log("Amount (per 10000):", amount);
            console2.log("Percentage:", amount / 100, "%");
        } catch {
            console2.log("Could not query royalty info");
        }

        // Summary
        console2.log("");
        console2.log("=== SUMMARY ===");
        if (currentValidator == NEW_VALIDATOR_V3) {
            console2.log("[OK] No migration needed. Collection uses v3 validator.");
        } else {
            console2.log("[ACTION REQUIRED] Migrate to v3 validator to enforce OpenSea royalties.");
        }
    }
}
