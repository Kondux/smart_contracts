// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title UpgradeImplementation
 * @notice Deploys a new KonduxImplementation and upgrades the beacon
 */
contract UpgradeImplementationScript is Script {
    // Mainnet factory address
    address constant FACTORY = 0xa265a01205f304F2652277AaC924AB56D2e0Cf77;

    function run() external {
        uint256 pk = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(pk);

        console2.log("Deployer:", deployer);
        console2.log("Factory:", FACTORY);

        KonduxBeaconFactory factory = KonduxBeaconFactory(FACTORY);
        UpgradeableBeacon beacon = factory.beacon();

        // Get current implementation
        address currentImpl = beacon.implementation();
        console2.log("Current Implementation:", currentImpl);

        vm.startBroadcast(pk);

        // Deploy new implementation
        KonduxImplementation newImpl = new KonduxImplementation();
        console2.log("New Implementation:", address(newImpl));

        // Upgrade beacon to new implementation
        factory.upgradeImplementation(address(newImpl));
        console2.log("Beacon upgraded!");

        vm.stopBroadcast();

        // Verify upgrade
        address updatedImpl = beacon.implementation();
        console2.log("Updated Implementation:", updatedImpl);
        require(updatedImpl == address(newImpl), "Upgrade failed");

        console2.log("\n=== Upgrade Complete ===");
        console2.log("All beacon proxies now use the new implementation with:");
        console2.log("  - safeMint registers recipient as creator");
        console2.log("  - getCreator(tokenId) function available");
    }
}
