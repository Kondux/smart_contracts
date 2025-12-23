// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {KonduxImplementation} from "../contracts/KonduxImplementation.sol";

interface IProxy {
    function implementation() external view returns (address);
}

interface IERC1967 {
    function upgradeToAndCall(address newImplementation, bytes memory data) external;
    function upgradeTo(address newImplementation) external;
}

/**
 * @title UpgradeKonduxImplementation
 * @notice Deploys a new KonduxImplementation and upgrades the proxy
 * @dev The proxy at 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D must support upgrades
 */
contract UpgradeKonduxImplementationScript is Script {
    address constant NFT_PROXY = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;

    function run() external {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Upgrade KonduxImplementation ===");
        console2.log("Deployer:", deployer);
        console2.log("NFT Proxy:", NFT_PROXY);
        console2.log("");

        // Check current implementation
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 currentImpl = vm.load(NFT_PROXY, implSlot);
        address currentImplAddr = address(uint160(uint256(currentImpl)));
        console2.log("Current implementation:", currentImplAddr);

        // Check admin slot
        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 admin = vm.load(NFT_PROXY, adminSlot);
        address adminAddr = address(uint160(uint256(admin)));
        console2.log("Proxy admin:", adminAddr);
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Deploy new implementation
        KonduxImplementation newImpl = new KonduxImplementation();
        console2.log("New implementation deployed:", address(newImpl));

        // Attempt upgrade - this will only work if:
        // 1. The deployer is the proxy admin, OR
        // 2. The implementation has UUPS upgrade functions
        //
        // If neither is true, this will revert and you'll need to
        // add UUPS to KonduxImplementation and redeploy.

        // Try low-level upgrade call
        (bool success,) = NFT_PROXY.call(
            abi.encodeWithSignature("upgradeTo(address)", address(newImpl))
        );

        if (success) {
            console2.log("SUCCESS: Proxy upgraded to new implementation");
        } else {
            console2.log("FAILED: upgradeTo() not available on proxy");
            console2.log("");
            console2.log("The proxy may not support direct upgrades.");
            console2.log("Options:");
            console2.log("1. Add UUPSUpgradeable to KonduxImplementation");
            console2.log("2. Use a ProxyAdmin if one exists");
            console2.log("3. Deploy a new collection with the updated implementation");
        }

        vm.stopBroadcast();
    }
}
