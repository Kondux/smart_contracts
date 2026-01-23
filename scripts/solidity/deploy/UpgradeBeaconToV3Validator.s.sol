// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title UpgradeBeaconToV3Validator
 * @notice Upgrades the beacon implementation to use v3 transfer validator for ALL cloned collections
 * @dev This script:
 *      1. Deploys a new KonduxImplementation with DEFAULT_TRANSFER_VALIDATOR = v3
 *      2. Calls factory.upgradeImplementation() to upgrade the beacon
 *      3. ALL collections using the beacon automatically get v3 validator
 *
 *      This fixes OpenSea royalty enforcement for all existing and future clones.
 *
 * Usage:
 *   # Dry run (check current state)
 *   forge script scripts/solidity/deploy/UpgradeBeaconToV3Validator.s.sol:CheckBeaconStateScript \
 *       --rpc-url mainnet -vvv
 *
 *   # Deploy new implementation and upgrade beacon
 *   forge script scripts/solidity/deploy/UpgradeBeaconToV3Validator.s.sol \
 *       --rpc-url mainnet --broadcast --verify -vvv
 *
 * Environment variables:
 *   PROD_DEPLOYER_PK - Private key of factory admin (required for upgrade)
 *   FACTORY_ADDRESS - (Optional) Override factory address
 */
contract UpgradeBeaconToV3ValidatorScript is Script {
    // Mainnet factory address (owns the beacon)
    address public constant DEFAULT_FACTORY = 0x0855A3063326623C22E62A376cC9e1715e6Da9A9;

    // Mainnet beacon address
    address public constant DEFAULT_BEACON = 0x5853D179DfD8059F50737417FaBb906dd9702F2C;

    // V3 validator that has OpenSea SignedZone as authorizer
    address public constant NEW_VALIDATOR_V3 = 0x721C0078c2328597Ca70F5451ffF5A7B38D4E947;

    // Old validator (for reference)
    address public constant OLD_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    function run() external {
        address factoryAddress = vm.envOr("FACTORY_ADDRESS", DEFAULT_FACTORY);

        console2.log("=== Upgrade Beacon to V3 Validator ===");
        console2.log("");
        console2.log("Factory:", factoryAddress);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        KonduxBeaconFactory factory = KonduxBeaconFactory(factoryAddress);
        UpgradeableBeacon beacon = UpgradeableBeacon(DEFAULT_BEACON);

        // Check current state
        address currentImpl = beacon.implementation();
        console2.log("--- Current State ---");
        console2.log("Beacon:", DEFAULT_BEACON);
        console2.log("Current Implementation:", currentImpl);

        // Check the current DEFAULT_TRANSFER_VALIDATOR in the implementation
        address currentValidator;
        try KonduxImplementation(payable(currentImpl)).DEFAULT_TRANSFER_VALIDATOR() returns (address v) {
            currentValidator = v;
        } catch {
            currentValidator = address(0);
        }
        console2.log("Current DEFAULT_TRANSFER_VALIDATOR:", currentValidator);

        if (currentValidator == NEW_VALIDATOR_V3) {
            console2.log("");
            console2.log("[OK] Implementation already uses v3 validator!");
            console2.log("No upgrade needed.");
            return;
        }

        if (currentValidator == OLD_VALIDATOR) {
            console2.log("Validator Version: V1/V2 (OLD - needs upgrade)");
        }

        // Check admin access on factory
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("");
        console2.log("Deployer:", deployer);

        bytes32 adminRole = factory.DEFAULT_ADMIN_ROLE();
        bool isAdmin = factory.hasRole(adminRole, deployer);

        if (!isAdmin) {
            console2.log("");
            console2.log("[ERROR] Deployer is NOT a factory admin!");
            console2.log("Only factory admins can upgrade the implementation.");
            revert("Deployer is not factory admin");
        }
        console2.log("Deployer is factory admin: YES");

        // Deploy new implementation
        console2.log("");
        console2.log("=== Deploying New Implementation ===");

        vm.startBroadcast(deployerKey);

        // Deploy new implementation with v3 validator
        KonduxImplementation newImpl = new KonduxImplementation();
        console2.log("New Implementation deployed:", address(newImpl));

        // Verify the new implementation has v3 validator
        address newImplValidator = newImpl.DEFAULT_TRANSFER_VALIDATOR();
        console2.log("New DEFAULT_TRANSFER_VALIDATOR:", newImplValidator);

        if (newImplValidator != NEW_VALIDATOR_V3) {
            console2.log("");
            console2.log("[ERROR] New implementation does not have v3 validator!");
            console2.log("Expected:", NEW_VALIDATOR_V3);
            console2.log("Got:", newImplValidator);
            revert("Implementation validator mismatch");
        }

        // Upgrade beacon via factory
        console2.log("");
        console2.log("=== Upgrading Beacon via Factory ===");
        console2.log("Old Implementation:", currentImpl);
        console2.log("New Implementation:", address(newImpl));

        factory.upgradeImplementation(address(newImpl));
        console2.log("Beacon upgraded via factory.upgradeImplementation()!");

        vm.stopBroadcast();

        // Verify upgrade
        console2.log("");
        console2.log("=== Post-Upgrade Verification ===");

        address verifyImpl = beacon.implementation();
        console2.log("Beacon Implementation:", verifyImpl);
        console2.log("Matches new impl:", verifyImpl == address(newImpl) ? "YES" : "NO");

        console2.log("");
        console2.log("=== SUCCESS ===");
        console2.log("Beacon has been upgraded to use v3 transfer validator.");
        console2.log("");
        console2.log("What this means:");
        console2.log("  - ALL collections using this beacon now use v3 validator");
        console2.log("  - Collections that haven't explicitly set a validator");
        console2.log("    will automatically use v3 for OpenSea royalty enforcement");
        console2.log("  - New clones will also use v3 by default");
        console2.log("");
        console2.log("IMPORTANT: Collections that explicitly called setTransferValidator()");
        console2.log("           with the old validator will still use the old one.");
        console2.log("           Those need FixExplicitValidatorCollectionsScript to fix manually.");
    }
}

/**
 * @title CheckBeaconStateScript
 * @notice Read-only script to check current beacon and implementation state
 */
contract CheckBeaconStateScript is Script {
    address public constant DEFAULT_FACTORY = 0x0855A3063326623C22E62A376cC9e1715e6Da9A9;
    address public constant DEFAULT_BEACON = 0x5853D179DfD8059F50737417FaBb906dd9702F2C;
    address public constant NEW_VALIDATOR_V3 = 0x721C0078c2328597Ca70F5451ffF5A7B38D4E947;
    address public constant OLD_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    // Known collections to check
    address public constant KONDUX_OMNIFORGE = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;

    function run() external view {
        console2.log("=== Beacon State Check (Read-Only) ===");
        console2.log("");
        console2.log("Factory:", DEFAULT_FACTORY);
        console2.log("Beacon:", DEFAULT_BEACON);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        KonduxBeaconFactory factory = KonduxBeaconFactory(DEFAULT_FACTORY);
        UpgradeableBeacon beacon = UpgradeableBeacon(DEFAULT_BEACON);

        // Beacon info
        console2.log("--- Beacon Info ---");
        address currentImpl = beacon.implementation();
        address beaconOwner = beacon.owner();
        console2.log("Implementation:", currentImpl);
        console2.log("Beacon Owner:", beaconOwner);
        console2.log("Owner is Factory:", beaconOwner == DEFAULT_FACTORY ? "YES" : "NO");

        // Implementation info
        console2.log("");
        console2.log("--- Implementation Info ---");

        address implValidator;
        try KonduxImplementation(payable(currentImpl)).DEFAULT_TRANSFER_VALIDATOR() returns (address v) {
            implValidator = v;
            console2.log("DEFAULT_TRANSFER_VALIDATOR:", implValidator);

            if (implValidator == NEW_VALIDATOR_V3) {
                console2.log("Version: V3 (LATEST - OK)");
            } else if (implValidator == OLD_VALIDATOR) {
                console2.log("Version: V1/V2 (OLD - needs upgrade)");
            } else {
                console2.log("Version: Unknown");
            }
        } catch {
            console2.log("Could not read DEFAULT_TRANSFER_VALIDATOR");
        }

        // Check a known collection
        console2.log("");
        console2.log("--- Collection Check: Kondux Omniforge ---");
        console2.log("Address:", KONDUX_OMNIFORGE);

        KonduxImplementation collection = KonduxImplementation(payable(KONDUX_OMNIFORGE));

        address collectionValidator = collection.getTransferValidator();
        console2.log("Current Validator:", collectionValidator);

        if (collectionValidator == NEW_VALIDATOR_V3) {
            console2.log("Status: Using V3 (OK)");
        } else if (collectionValidator == OLD_VALIDATOR) {
            console2.log("Status: Using V1/V2 (needs fix)");
        } else if (collectionValidator == address(0)) {
            console2.log("Status: No validator set");
        } else {
            console2.log("Status: Using custom validator");
        }

        // Summary
        console2.log("");
        console2.log("=== SUMMARY ===");

        if (implValidator == NEW_VALIDATOR_V3) {
            console2.log("[OK] Beacon implementation uses v3 validator.");
            if (collectionValidator != NEW_VALIDATOR_V3) {
                console2.log("[!] But Kondux Omniforge has an explicit validator set.");
                console2.log("    It needs FixExplicitValidatorCollectionsScript to fix.");
            }
        } else {
            console2.log("[ACTION REQUIRED] Beacon needs upgrade to v3 validator.");
            console2.log("");
            console2.log("Run:");
            console2.log("  forge script scripts/solidity/deploy/UpgradeBeaconToV3Validator.s.sol \\");
            console2.log("      --rpc-url mainnet --broadcast --verify -vvv");
        }
    }
}

/**
 * @title FixExplicitValidatorCollectionsScript
 * @notice Fixes collections that explicitly set the old validator (won't be fixed by beacon upgrade)
 * @dev Use this AFTER upgrading the beacon for collections that called setTransferValidator(oldValidator)
 */
contract FixExplicitValidatorCollectionsScript is Script {
    address public constant NEW_VALIDATOR_V3 = 0x721C0078c2328597Ca70F5451ffF5A7B38D4E947;
    address public constant OLD_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    address public constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address public constant SEAPORT_16 = 0x0000000000000068F116a894984e2DB1123eB395;
    address public constant SEAPORT_15 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;

    // Default target
    address public constant KONDUX_OMNIFORGE = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;

    function run() external {
        address collection = vm.envOr("TARGET_COLLECTION", KONDUX_OMNIFORGE);

        console2.log("=== Fix Explicit Validator Collection ===");
        console2.log("");
        console2.log("Collection:", collection);
        console2.log("");

        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);
        console2.log("Deployer:", deployer);

        KonduxImplementation kondux = KonduxImplementation(payable(collection));

        // Check current validator
        address currentValidator = kondux.getTransferValidator();
        console2.log("");
        console2.log("Current Validator:", currentValidator);

        if (currentValidator == NEW_VALIDATOR_V3) {
            console2.log("[OK] Already using v3 validator. No action needed.");
            return;
        }

        if (currentValidator == OLD_VALIDATOR) {
            console2.log("Status: Using V1/V2 (OLD - will fix)");
        } else {
            console2.log("Status: Using unknown validator");
        }

        // Check admin access
        bytes32 adminRole = kondux.DEFAULT_ADMIN_ROLE();
        bool isAdmin = kondux.hasRole(adminRole, deployer);

        if (!isAdmin) {
            console2.log("");
            console2.log("[ERROR] Deployer is not admin of this collection!");
            revert("Not admin");
        }
        console2.log("Deployer is admin: YES");

        vm.startBroadcast(deployerKey);

        // Switch to v3 validator
        console2.log("");
        console2.log("Step 1: Switching to v3 validator...");
        kondux.setTransferValidator(NEW_VALIDATOR_V3);
        console2.log("  -> Validator switched!");

        // Set up security policy on new validator
        console2.log("");
        console2.log("Step 2: Setting up security policy on v3 validator...");
        kondux.setToDefaultSecurityPolicy();
        console2.log("  -> Default security policy set (whitelist with Seaport 1.6)!");

        // Add OpenSea conduit and Seaport 1.5
        console2.log("");
        console2.log("Step 3: Adding OpenSea conduit to whitelist...");
        address[] memory operators = new address[](2);
        operators[0] = OPENSEA_CONDUIT;
        operators[1] = SEAPORT_15;
        kondux.addAccountsToWhitelist(operators);
        console2.log("  -> OpenSea Conduit added!");
        console2.log("  -> Seaport 1.5 added!");

        vm.stopBroadcast();

        // Verify
        address newValidator = kondux.getTransferValidator();
        console2.log("");
        console2.log("=== Verification ===");
        console2.log("New Validator:", newValidator);
        console2.log("Is V3:", newValidator == NEW_VALIDATOR_V3 ? "YES" : "NO");

        console2.log("");
        console2.log("=== SUCCESS ===");
        console2.log("Collection has been migrated to v3 validator.");
        console2.log("OpenSea Seaport Hooks will now enforce royalties.");
    }
}
