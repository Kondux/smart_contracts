// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";

/**
 * @title DeployNewFactoryV2
 * @notice Deploys a new KonduxBeaconFactory with proper marketplace security auto-configuration
 * @dev This factory version includes _configureMarketplaceSecurity() which automatically:
 *      1. Calls setToDefaultSecurityPolicy() to set security level 4
 *      2. Creates whitelist with Seaport 1.6
 *      3. Adds OpenSea Conduit to whitelist
 *
 * The new factory will use the V5 KonduxImplementation with updated Transfer Validator.
 *
 * Usage:
 *   # Dry-run
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployNewFactoryV2.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf'"
 *
 *   # Broadcast
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployNewFactoryV2.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf' --broadcast"
 */
contract DeployNewFactoryV2 is Script {
    // Limit Break Transfer Validator V5
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    struct DeployResult {
        address implementation;
        address factory;
        address beacon;
    }

    function run() external returns (DeployResult memory result) {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Deploy New Factory V2 with Security Auto-Config ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer Balance:", deployer.balance);
        console2.log("");

        require(block.chainid == 1, "This script is for mainnet only");

        vm.startBroadcast(deployerKey);

        // Step 1: Deploy new KonduxImplementation with V5 Transfer Validator
        console2.log("Step 1: Deploying KonduxImplementation (V5 validator)...");
        KonduxImplementation implementation = new KonduxImplementation();
        result.implementation = address(implementation);
        console2.log("  Implementation:", address(implementation));
        console2.log("  DEFAULT_TRANSFER_VALIDATOR:", implementation.DEFAULT_TRANSFER_VALIDATOR());
        require(
            implementation.DEFAULT_TRANSFER_VALIDATOR() == TRANSFER_VALIDATOR_V5,
            "Implementation does not have V5 validator"
        );
        console2.log("  PASS: V5 validator confirmed");
        console2.log("");

        // Step 2: Deploy new KonduxBeaconFactory with the new implementation
        // The factory creates an UpgradeableBeacon pointing to the implementation
        console2.log("Step 2: Deploying KonduxBeaconFactory V2...");
        KonduxBeaconFactory factory = new KonduxBeaconFactory(address(implementation));
        result.factory = address(factory);
        result.beacon = address(factory.beacon());
        console2.log("  Factory:", address(factory));
        console2.log("  Beacon:", address(factory.beacon()));
        console2.log("  Beacon Implementation:", factory.beacon().implementation());
        console2.log("");

        // Step 3: Grant CLONE_DEPLOYER_ROLE to deployer
        console2.log("Step 3: Granting CLONE_DEPLOYER_ROLE to deployer...");
        factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), deployer);
        console2.log("  CLONE_DEPLOYER_ROLE granted to:", deployer);
        console2.log("");

        // Step 4: Disable public deployment (only CLONE_DEPLOYER_ROLE can deploy)
        console2.log("Step 4: Disabling public deployment...");
        factory.setPublicDeployment(false);
        console2.log("  publicDeployment:", factory.publicDeployment());
        console2.log("");

        vm.stopBroadcast();

        // Print summary
        _printSummary(result, deployer);

        return result;
    }

    function _printSummary(DeployResult memory result, address deployer) internal pure {
        console2.log("=== DEPLOYMENT SUMMARY ===");
        console2.log("");
        console2.log("New Contracts:");
        console2.log("  Implementation (V5):", result.implementation);
        console2.log("  Factory (V2):", result.factory);
        console2.log("  Beacon:", result.beacon);
        console2.log("");
        console2.log("Configuration:");
        console2.log("  Transfer Validator: V5 (0x721C008fdff27BF06E7E123956E2Fe03B63342e3)");
        console2.log("  Public Deployment: false");
        console2.log("  CLONE_DEPLOYER_ROLE:", deployer);
        console2.log("");
        console2.log("Features (V2):");
        console2.log("  - Auto security policy on clone deployment");
        console2.log("  - Seaport 1.6 whitelisted");
        console2.log("  - OpenSea Conduit whitelisted");
        console2.log("  - Security Level 4 (Operator Whitelist, OTC Disabled)");
        console2.log("");
        console2.log("--- Export Variables ---");
        console2.log(string.concat("FACTORY_V2_ADDRESS=", vm.toString(result.factory)));
        console2.log(string.concat("IMPLEMENTATION_V5_ADDRESS=", vm.toString(result.implementation)));
        console2.log(string.concat("BEACON_ADDRESS=", vm.toString(result.beacon)));
    }
}
