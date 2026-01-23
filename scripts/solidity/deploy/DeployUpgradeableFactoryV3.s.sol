// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactoryUpgradeable} from "contracts/KonduxBeaconFactoryUpgradeable.sol";

/**
 * @title DeployUpgradeableFactoryV3
 * @notice Deploys the UUPS-upgradeable KonduxBeaconFactory (V3)
 * @dev This deploys:
 *      1. KonduxImplementation (V5 Transfer Validator)
 *      2. KonduxBeaconFactoryUpgradeable implementation
 *      3. ERC1967Proxy pointing to the factory implementation
 *
 * The factory is now upgradeable via UUPS pattern.
 * The beacon can be transferred to a new factory if needed.
 *
 * Usage:
 *   # Dry-run
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0x588ec1f77f2c8d32662bcc1f024e639af152b623182407c5f659a0b3c6ab725d \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployUpgradeableFactoryV3.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf'"
 *
 *   # Broadcast
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0x588ec1f77f2c8d32662bcc1f024e639af152b623182407c5f659a0b3c6ab725d \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployUpgradeableFactoryV3.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf' --broadcast"
 */
contract DeployUpgradeableFactoryV3 is Script {
    // Limit Break Transfer Validator V5
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    struct DeployResult {
        address nftImplementation;
        address factoryImplementation;
        address factoryProxy;
        address beacon;
    }

    function run() external returns (DeployResult memory result) {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Deploy Upgradeable Factory V3 ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer Balance:", deployer.balance);
        console2.log("");

        require(block.chainid == 1, "This script is for mainnet only");

        vm.startBroadcast(deployerKey);

        // Step 1: Deploy KonduxImplementation with V5 Transfer Validator
        console2.log("Step 1: Deploying KonduxImplementation (V5)...");
        KonduxImplementation nftImpl = new KonduxImplementation();
        result.nftImplementation = address(nftImpl);
        console2.log("  NFT Implementation:", address(nftImpl));
        console2.log("  Transfer Validator:", nftImpl.DEFAULT_TRANSFER_VALIDATOR());
        require(
            nftImpl.DEFAULT_TRANSFER_VALIDATOR() == TRANSFER_VALIDATOR_V5,
            "Wrong transfer validator"
        );
        console2.log("");

        // Step 2: Deploy KonduxBeaconFactoryUpgradeable implementation
        console2.log("Step 2: Deploying Factory Implementation...");
        KonduxBeaconFactoryUpgradeable factoryImpl = new KonduxBeaconFactoryUpgradeable();
        result.factoryImplementation = address(factoryImpl);
        console2.log("  Factory Implementation:", address(factoryImpl));
        console2.log("");

        // Step 3: Deploy ERC1967Proxy with factory implementation
        console2.log("Step 3: Deploying Factory Proxy (ERC1967)...");
        bytes memory initData = abi.encodeWithSelector(
            KonduxBeaconFactoryUpgradeable.initialize.selector,
            address(nftImpl),  // NFT implementation for beacon
            deployer           // Admin
        );
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImpl),
            initData
        );
        result.factoryProxy = address(factoryProxy);
        console2.log("  Factory Proxy:", address(factoryProxy));
        console2.log("");

        // Step 4: Verify deployment
        console2.log("Step 4: Verifying deployment...");
        KonduxBeaconFactoryUpgradeable factory = KonduxBeaconFactoryUpgradeable(address(factoryProxy));
        result.beacon = address(factory.beacon());
        
        console2.log("  Beacon:", address(factory.beacon()));
        console2.log("  Beacon Implementation:", factory.implementation());
        console2.log("  Beacon Owner:", factory.beaconOwner());
        console2.log("  Factory Version:", factory.version());
        console2.log("  Public Deployment:", factory.publicDeployment());
        console2.log("");

        // Verify roles
        console2.log("  Roles granted to deployer:");
        console2.log("    DEFAULT_ADMIN_ROLE:", factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), deployer));
        console2.log("    FEE_ADMIN_ROLE:", factory.hasRole(factory.FEE_ADMIN_ROLE(), deployer));
        console2.log("    UPGRADER_ROLE:", factory.hasRole(factory.UPGRADER_ROLE(), deployer));
        console2.log("    CLONE_DEPLOYER_ROLE:", factory.hasRole(factory.CLONE_DEPLOYER_ROLE(), deployer));
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
        console2.log("  NFT Implementation (V5):", result.nftImplementation);
        console2.log("  Factory Implementation:", result.factoryImplementation);
        console2.log("  Factory Proxy (USE THIS):", result.factoryProxy);
        console2.log("  Beacon:", result.beacon);
        console2.log("");
        console2.log("Configuration:");
        console2.log("  Transfer Validator: V5 (0x721C008fdff27BF06E7E123956E2Fe03B63342e3)");
        console2.log("  Factory Version: 1");
        console2.log("  Public Deployment: false");
        console2.log("  Admin:", deployer);
        console2.log("");
        console2.log("Upgrade Capabilities:");
        console2.log("  - Factory: UUPS upgradeable (call upgradeToAndCall)");
        console2.log("  - NFT Implementation: Via factory.upgradeImplementation()");
        console2.log("  - Beacon Ownership: Via factory.transferBeaconOwnership()");
        console2.log("");
        console2.log("--- Export Variables ---");
        console2.log(string.concat("FACTORY_V3_PROXY=", vm.toString(result.factoryProxy)));
        console2.log(string.concat("FACTORY_V3_IMPL=", vm.toString(result.factoryImplementation)));
        console2.log(string.concat("NFT_IMPLEMENTATION=", vm.toString(result.nftImplementation)));
        console2.log(string.concat("BEACON_ADDRESS=", vm.toString(result.beacon)));
    }
}
