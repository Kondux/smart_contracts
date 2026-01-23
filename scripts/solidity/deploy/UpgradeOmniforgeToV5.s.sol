// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";

/**
 * @title IKonduxBeaconFactoryLegacy
 * @notice Interface for the legacy factory that owns Omniforge's beacon
 */
interface IKonduxBeaconFactoryLegacy {
    function upgradeImplementation(address newImplementation) external;
    function beacon() external view returns (address);
}

interface IUpgradeableBeacon {
    function implementation() external view returns (address);
    function owner() external view returns (address);
}

/**
 * @title UpgradeOmniforgeToV5
 * @notice Upgrades Kondux Omniforge (CRTR) collection to V5 Transfer Validator and configures security
 * @dev This script:
 *      1. Upgrades the beacon to V5 implementation via the legacy factory
 *      2. Configures security policy on the collection (level 4 + OpenSea whitelist)
 *
 * Addresses:
 *   - Omniforge Collection: 0xaa030da0c99726f83e9959b450482fb00216c26d
 *   - Beacon: 0x5853d179dfd8059f50737417fabb906dd9702f2c
 *   - Legacy Factory (beacon owner): 0x0855A3063326623C22E62A376cC9e1715e6Da9A9
 *   - V5 Implementation: 0x82002F8ECAc10959128AAe042F985E91670946Eb
 *
 * Usage:
 *   # Dry-run
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/UpgradeOmniforgeToV5.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf'"
 *
 *   # Broadcast
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/UpgradeOmniforgeToV5.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf' --broadcast"
 */
contract UpgradeOmniforgeToV5 is Script {
    // Kondux Omniforge (CRTR) collection
    address constant OMNIFORGE_COLLECTION = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;
    
    // Legacy factory that owns the beacon
    address constant LEGACY_FACTORY = 0x0855A3063326623C22E62A376cC9e1715e6Da9A9;
    
    // Beacon address
    address constant BEACON = 0x5853D179DfD8059F50737417FaBb906dd9702F2C;
    
    // V5 Implementation with updated Transfer Validator
    address constant V5_IMPLEMENTATION = 0x82002F8ECAc10959128AAe042F985E91670946Eb;
    
    // Limit Break Transfer Validator V5
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    
    // OpenSea Conduit
    address constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    function run() external {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Upgrade Kondux Omniforge to V5 ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("");

        require(block.chainid == 1, "This script is for mainnet only");

        // Pre-flight checks
        console2.log("Pre-flight Checks:");
        
        IKonduxBeaconFactoryLegacy factory = IKonduxBeaconFactoryLegacy(LEGACY_FACTORY);
        IUpgradeableBeacon beacon = IUpgradeableBeacon(BEACON);
        KonduxImplementation collection = KonduxImplementation(payable(OMNIFORGE_COLLECTION));

        console2.log("  Collection:", OMNIFORGE_COLLECTION);
        console2.log("  Collection Name:", collection.name());
        console2.log("  Beacon:", BEACON);
        console2.log("  Beacon Owner:", beacon.owner());
        console2.log("  Current Implementation:", beacon.implementation());
        console2.log("  Current Transfer Validator:", collection.getTransferValidator());
        console2.log("");

        require(beacon.owner() == LEGACY_FACTORY, "Beacon not owned by legacy factory");
        
        vm.startBroadcast(deployerKey);

        // Step 1: Upgrade beacon to V5 implementation
        console2.log("Step 1: Upgrading beacon to V5 implementation...");
        console2.log("  Target Implementation:", V5_IMPLEMENTATION);
        factory.upgradeImplementation(V5_IMPLEMENTATION);
        console2.log("  Beacon upgraded!");
        console2.log("");

        // Step 2: Configure security policy on collection
        console2.log("Step 2: Configuring security policy...");
        console2.log("  Setting default security policy (Level 4 + Seaport whitelist)...");
        collection.setToDefaultSecurityPolicy();
        console2.log("  Security policy configured!");
        console2.log("");

        // Step 3: Add OpenSea Conduit to whitelist
        console2.log("Step 3: Adding OpenSea Conduit to whitelist...");
        address[] memory accounts = new address[](1);
        accounts[0] = OPENSEA_CONDUIT;
        collection.addAccountsToWhitelist(accounts);
        console2.log("  OpenSea Conduit added!");
        console2.log("");

        vm.stopBroadcast();

        // Verification
        console2.log("=== Verification ===");
        console2.log("  New Implementation:", beacon.implementation());
        console2.log("  New Transfer Validator:", collection.getTransferValidator());
        
        if (beacon.implementation() == V5_IMPLEMENTATION) {
            console2.log("  PASS: Implementation upgraded to V5");
        } else {
            console2.log("  FAIL: Implementation not upgraded!");
        }

        if (collection.getTransferValidator() == TRANSFER_VALIDATOR_V5) {
            console2.log("  PASS: Transfer Validator is V5");
        } else {
            console2.log("  WARNING: Transfer Validator not V5 - may need manual check");
        }

        console2.log("");
        console2.log("=== UPGRADE COMPLETE ===");
        console2.log("Kondux Omniforge (CRTR) is now running on V5 with OpenSea enforcement.");
    }
}
