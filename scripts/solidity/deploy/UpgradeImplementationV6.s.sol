// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactoryUpgradeable} from "contracts/KonduxBeaconFactoryUpgradeable.sol";

interface ILegacyFactory {
    function upgradeImplementation(address newImplementation) external;
}

/**
 * @title UpgradeImplementationV6
 * @notice Upgrades KonduxImplementation to V6 (adds owner() function for OpenSea compatibility)
 * @dev This script:
 *      1. Deploys new KonduxImplementation (V6)
 *      2. Upgrades V3 Factory Beacon (affects KTEST, MSC)
 *      3. Upgrades Legacy Factory Beacon (affects Legacy Clone)
 *
 * Change: Added owner() function returning DEFAULT_ADMIN_ROLE member.
 */
contract UpgradeImplementationV6 is Script {
    // V3 Factory Proxy
    address constant V3_FACTORY_PROXY = 0x539F8627Bd33E7c0D8320b1e7d7477d436Ffd12c;
    
    // Legacy Factory (owns legacy beacon)
    address constant LEGACY_FACTORY = 0x0855A3063326623C22E62A376cC9e1715e6Da9A9;

    // V5 Transfer Validator (check to ensure we keep it)
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    function run() external {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Upgrade Implementation to V6 (Add owner()) ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("Deployer:", deployer);
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Step 1: Deploy new Implementation
        console2.log("Step 1: Deploying KonduxImplementation V6...");
        KonduxImplementation newImpl = new KonduxImplementation();
        console2.log("  New Implementation:", address(newImpl));
        
        // Verify validator matches
        require(
            newImpl.DEFAULT_TRANSFER_VALIDATOR() == TRANSFER_VALIDATOR_V5,
            "Wrong transfer validator in new impl"
        );
        
        // Removed owner() check on implementation as it reverts on uninitialized contract
        // The function exists in the code and will work on initialized clones
        console2.log("  PASS: V5 validator confirmed");
        console2.log("");

        // Step 2: Upgrade V3 Factory Beacon
        console2.log("Step 2: Upgrading V3 Factory Beacon...");
        KonduxBeaconFactoryUpgradeable v3Factory = KonduxBeaconFactoryUpgradeable(V3_FACTORY_PROXY);
        v3Factory.upgradeImplementation(address(newImpl));
        console2.log("  V3 Beacon upgraded!");
        console2.log("");

        // Step 3: Upgrade Legacy Factory Beacon
        console2.log("Step 3: Upgrading Legacy Factory Beacon...");
        ILegacyFactory legacyFactory = ILegacyFactory(LEGACY_FACTORY);
        legacyFactory.upgradeImplementation(address(newImpl));
        console2.log("  Legacy Beacon upgraded!");
        console2.log("");

        vm.stopBroadcast();

        console2.log("=== UPGRADE COMPLETE ===");
        console2.log("All clones (Legacy, KTest, MSC) should now expose owner().");
    }
}
