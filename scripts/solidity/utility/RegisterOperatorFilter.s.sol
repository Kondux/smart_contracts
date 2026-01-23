// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {IOperatorFilterRegistry} from "contracts/interfaces/IOperatorFilterRegistry.sol";

/**
 * @title RegisterOperatorFilter
 * @notice Registers a collection with OpenSea's Operator Filter Registry for royalty enforcement
 * @dev This is REQUIRED for OpenSea to enforce royalties. ERC721C alone is not sufficient.
 *
 *      OpenSea uses two separate systems:
 *      1. Operator Filter Registry - Determines if buyers can skip royalties in OpenSea UI
 *      2. ERC721C Transfer Validator - Blocks unauthorized operators from executing transfers
 *
 *      Without OFR registration, OpenSea shows a "skip royalties" toggle to buyers.
 *
 * Usage:
 *   # Check current status (read-only)
 *   forge script scripts/solidity/utility/RegisterOperatorFilter.s.sol:CheckOperatorFilterScript \
 *       --rpc-url mainnet -vvv
 *
 *   # Register with OpenSea's default subscription
 *   forge script scripts/solidity/utility/RegisterOperatorFilter.s.sol \
 *       --rpc-url mainnet --broadcast -vvv
 *
 * Environment variables:
 *   PROD_DEPLOYER_PK - Admin private key (required for broadcast)
 *   TARGET_COLLECTION - Override target address (optional, defaults to Kondux Omniforge)
 */
contract RegisterOperatorFilterScript is Script {
    // Default target - Kondux Omniforge mainnet
    address public constant DEFAULT_TARGET = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;

    // OpenSea's Operator Filter Registry (same address on mainnet, polygon, arbitrum, optimism, etc.)
    address public constant OPERATOR_FILTER_REGISTRY = 0x000000000000AAeB6D7670E522A718067333cd4E;

    // OpenSea's default curated subscription (blocks known royalty-bypassing marketplaces)
    address public constant OPENSEA_DEFAULT_SUBSCRIPTION = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    function run() external {
        address target = vm.envOr("TARGET_COLLECTION", DEFAULT_TARGET);

        console2.log("=== Register Operator Filter Script ===");
        console2.log("");
        console2.log("Target collection:", target);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        IOperatorFilterRegistry registry = IOperatorFilterRegistry(OPERATOR_FILTER_REGISTRY);

        // Check current registration status
        bool isRegistered = registry.isRegistered(target);
        console2.log("--- Current Status ---");
        console2.log("Operator Filter Registry:", OPERATOR_FILTER_REGISTRY);
        console2.log("Is Registered:", isRegistered ? "YES" : "NO");

        if (isRegistered) {
            address subscription = registry.subscriptionOf(target);
            console2.log("Subscription:", subscription);
            if (subscription == OPENSEA_DEFAULT_SUBSCRIPTION) {
                console2.log("Subscribed to: OpenSea Default (recommended)");
            } else if (subscription == address(0)) {
                console2.log("Subscribed to: None (custom list)");
            } else {
                console2.log("Subscribed to: Custom address");
            }
            console2.log("");
            console2.log("[OK] Collection is already registered with Operator Filter Registry.");
            console2.log("OpenSea should enforce royalties for this collection.");
            return;
        }

        // Verify we have admin access
        KonduxImplementation kondux = KonduxImplementation(payable(target));
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("");
        console2.log("Deployer:", deployer);

        bytes32 adminRole = kondux.DEFAULT_ADMIN_ROLE();
        bool isAdmin = kondux.hasRole(adminRole, deployer);

        if (!isAdmin) {
            console2.log("");
            console2.log("[ERROR] Deployer is NOT an admin of the collection!");
            console2.log("Only admins can register the collection with Operator Filter Registry.");
            revert("Deployer is not admin");
        }
        console2.log("Deployer has admin role: YES");

        // Check if collection has registerAndSubscribe function
        // The collection needs to call the registry on its own behalf
        console2.log("");
        console2.log("=== Registering with Operator Filter Registry ===");
        console2.log("");
        console2.log("Subscription:", OPENSEA_DEFAULT_SUBSCRIPTION);
        console2.log("This subscribes to OpenSea's curated list of blocked operators.");

        vm.startBroadcast(deployerKey);

        // The collection must register itself - call through the collection
        // First, check if the collection has a registerOperatorFilter function
        (bool hasFunction,) = target.staticcall(
            abi.encodeWithSignature("registerOperatorFilter()")
        );

        if (hasFunction) {
            // Collection has built-in function
            console2.log("Using collection's registerOperatorFilter()...");
            (bool success,) = target.call(
                abi.encodeWithSignature("registerOperatorFilter()")
            );
            require(success, "registerOperatorFilter failed");
        } else {
            // Need to register directly - this requires the collection to call the registry
            // Since the collection doesn't have the function, we need a different approach
            console2.log("");
            console2.log("[!] Collection does not have registerOperatorFilter() function.");
            console2.log("");
            console2.log("You need to add this function to KonduxImplementation and upgrade,");
            console2.log("or use a workaround script that calls the registry from the collection context.");
            console2.log("");
            console2.log("See: scripts/solidity/utility/RegisterOperatorFilter.s.sol:UpgradeAndRegisterScript");
            revert("Collection needs registerOperatorFilter function");
        }

        vm.stopBroadcast();

        // Verify registration
        console2.log("");
        console2.log("=== Post-Registration Verification ===");

        isRegistered = registry.isRegistered(target);
        console2.log("Is Registered:", isRegistered ? "YES" : "NO");

        if (isRegistered) {
            console2.log("");
            console2.log("=== SUCCESS ===");
            console2.log("Collection is now registered with OpenSea's Operator Filter Registry.");
            console2.log("OpenSea will enforce royalties for this collection.");
        } else {
            console2.log("");
            console2.log("[ERROR] Registration verification failed.");
        }
    }
}

/**
 * @title CheckOperatorFilterScript
 * @notice Read-only script to check Operator Filter Registry status
 */
contract CheckOperatorFilterScript is Script {
    address public constant DEFAULT_TARGET = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;
    address public constant OPERATOR_FILTER_REGISTRY = 0x000000000000AAeB6D7670E522A718067333cd4E;
    address public constant OPENSEA_DEFAULT_SUBSCRIPTION = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    function run() external view {
        address target = vm.envOr("TARGET_COLLECTION", DEFAULT_TARGET);

        console2.log("=== Operator Filter Registry Check (Read-Only) ===");
        console2.log("");
        console2.log("Target collection:", target);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        IOperatorFilterRegistry registry = IOperatorFilterRegistry(OPERATOR_FILTER_REGISTRY);

        console2.log("--- Operator Filter Registry Status ---");
        console2.log("Registry:", OPERATOR_FILTER_REGISTRY);

        bool isRegistered = registry.isRegistered(target);
        console2.log("Is Registered:", isRegistered ? "YES" : "NO");

        if (isRegistered) {
            address subscription = registry.subscriptionOf(target);
            console2.log("Subscription:", subscription);

            if (subscription == OPENSEA_DEFAULT_SUBSCRIPTION) {
                console2.log("Subscription Type: OpenSea Default (recommended)");
            } else if (subscription == address(0)) {
                console2.log("Subscription Type: None (custom list)");
            } else {
                console2.log("Subscription Type: Custom");
            }

            console2.log("");
            console2.log("=== SUMMARY ===");
            console2.log("[OK] Collection is registered with Operator Filter Registry.");
            console2.log("OpenSea should enforce royalties for this collection.");
        } else {
            console2.log("");
            console2.log("=== SUMMARY ===");
            console2.log("[!] Collection is NOT registered with Operator Filter Registry.");
            console2.log("OpenSea will show 'skip royalties' toggle to buyers.");
            console2.log("");
            console2.log("To fix, either:");
            console2.log("1. Add registerOperatorFilter() to KonduxImplementation and upgrade");
            console2.log("2. Or call registry.registerAndSubscribe() from the collection");
            console2.log("");
            console2.log("Command to register (after adding function):");
            console2.log("  forge script scripts/solidity/utility/RegisterOperatorFilter.s.sol \\");
            console2.log("      --rpc-url mainnet --broadcast -vvv");
        }
    }
}
