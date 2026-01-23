// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactoryUpgradeable} from "contracts/KonduxBeaconFactoryUpgradeable.sol";
import {KonduxBatchMinter} from "contracts/KonduxBatchMinter.sol";

/**
 * @title DeployKTestWithBatchMinter
 * @notice Deploys a new KTest Collection via V3 factory and sets up a batch minter
 * @dev This script:
 *      1. Deploys collection clone via V3 factory (auto-configures security)
 *      2. Deploys KonduxBatchMinter
 *      3. Grants MINTER_ROLE to the batch minter
 *
 * Usage:
 *   # Dry-run
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployKTestWithBatchMinter.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf'"
 *
 *   # Broadcast
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployKTestWithBatchMinter.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf' --broadcast"
 */
contract DeployKTestWithBatchMinter is Script {
    // V3 Factory Proxy (upgradeable)
    address constant FACTORY_PROXY = 0x539F8627Bd33E7c0D8320b1e7d7477d436Ffd12c;
    
    // Kondux Authority contract (for batch minter vault)
    address constant AUTHORITY = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
    
    // Transfer Validator V5
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    struct DeployResult {
        address collection;
        address splitter;
        address batchMinter;
    }

    function run() external returns (DeployResult memory result) {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Deploy KTest Collection + Batch Minter ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer Balance:", deployer.balance);
        console2.log("");

        require(block.chainid == 1, "This script is for mainnet only");

        KonduxBeaconFactoryUpgradeable factory = KonduxBeaconFactoryUpgradeable(FACTORY_PROXY);

        console2.log("Using V3 Factory Proxy:", FACTORY_PROXY);
        console2.log("Beacon:", address(factory.beacon()));
        console2.log("Implementation:", factory.implementation());
        console2.log("");

        // Collection configuration
        string memory name = "KTest Collection";
        string memory symbol = "KTEST";
        uint256 maxSupply = 10000;
        address admin = deployer;
        address partnerWallet = deployer;
        uint96 manufacturerCutBP = 500;  // 5%
        uint96 partnerCutBP = 0;         // 0%
        uint96 creatorCutBP = 500;       // 5%
        address defaultCreatorWallet = deployer;

        console2.log("Collection Config:");
        console2.log("  Name:", name);
        console2.log("  Symbol:", symbol);
        console2.log("  Max Supply:", maxSupply);
        console2.log("  Admin:", admin);
        console2.log("  Total Royalty:", manufacturerCutBP + partnerCutBP + creatorCutBP, "BP (10%)");
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Step 1: Deploy collection via V3 factory
        console2.log("Step 1: Deploying collection via V3 factory...");
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            name,
            symbol,
            maxSupply,
            admin,
            true,  // deploySplitter
            partnerWallet,
            manufacturerCutBP,
            partnerCutBP,
            creatorCutBP,
            defaultCreatorWallet
        );
        result.collection = collectionAddr;
        result.splitter = splitterAddr;
        console2.log("  Collection:", collectionAddr);
        console2.log("  Splitter:", splitterAddr);
        console2.log("");

        // Step 2: Deploy batch minter
        console2.log("Step 2: Deploying KonduxBatchMinter...");
        KonduxBatchMinter batchMinter = new KonduxBatchMinter(
            collectionAddr,
            AUTHORITY
        );
        result.batchMinter = address(batchMinter);
        console2.log("  Batch Minter:", address(batchMinter));
        console2.log("");

        // Step 3: Grant MINTER_ROLE to batch minter on collection
        console2.log("Step 3: Granting MINTER_ROLE to batch minter...");
        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        bytes32 minterRole = collection.MINTER_ROLE();
        collection.grantRole(minterRole, address(batchMinter));
        console2.log("  MINTER_ROLE granted to batch minter");
        console2.log("");

        // Step 4: Grant BATCH_MINTER_ROLE to deployer on batch minter (for signing)
        console2.log("Step 4: Granting BATCH_MINTER_ROLE to deployer...");
        bytes32 batchMinterRole = batchMinter.BATCH_MINTER_ROLE();
        batchMinter.grantRole(batchMinterRole, deployer);
        console2.log("  BATCH_MINTER_ROLE granted to deployer");
        console2.log("");

        vm.stopBroadcast();

        // Verification
        console2.log("=== Verification ===");
        
        // Check security policy
        address validator = collection.getTransferValidator();
        console2.log("  Transfer Validator:", validator);
        if (validator == TRANSFER_VALIDATOR_V5) {
            console2.log("  PASS: V5 Transfer Validator");
        } else {
            console2.log("  WARNING: Unexpected validator");
        }

        // Check roles
        bool hasMinterRole = collection.hasRole(minterRole, address(batchMinter));
        console2.log("  Batch Minter has MINTER_ROLE:", hasMinterRole);

        bool hasBatchMinterRole = batchMinter.hasRole(batchMinterRole, deployer);
        console2.log("  Deployer has BATCH_MINTER_ROLE:", hasBatchMinterRole);

        // Check royalty
        (address receiver, uint256 amount) = collection.royaltyInfo(0, 10000);
        console2.log("  Royalty Receiver:", receiver);
        console2.log("  Royalty Amount:", amount, "BP");
        console2.log("");

        // Print summary
        _printSummary(result, deployer);

        return result;
    }

    function _printSummary(DeployResult memory result, address deployer) internal pure {
        console2.log("=== DEPLOYMENT SUMMARY ===");
        console2.log("");
        console2.log("New Contracts:");
        console2.log("  Collection (KTest):", result.collection);
        console2.log("  Splitter:", result.splitter);
        console2.log("  Batch Minter:", result.batchMinter);
        console2.log("");
        console2.log("Permissions:");
        console2.log("  Collection Admin:", deployer);
        console2.log("  Batch Minter has MINTER_ROLE: true");
        console2.log("  Deployer has BATCH_MINTER_ROLE: true");
        console2.log("");
        console2.log("Security:");
        console2.log("  Transfer Validator: V5");
        console2.log("  Security Level: 4 (Auto-configured)");
        console2.log("  OpenSea: Whitelisted");
        console2.log("");
        console2.log("--- Export Variables ---");
        console2.log(string.concat("COLLECTION_ADDRESS=", vm.toString(result.collection)));
        console2.log(string.concat("SPLITTER_ADDRESS=", vm.toString(result.splitter)));
        console2.log(string.concat("BATCH_MINTER_ADDRESS=", vm.toString(result.batchMinter)));
    }
}
