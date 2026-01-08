// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";
import {KonduxRoyaltySplitter} from "contracts/KonduxRoyaltySplitter.sol";
import {KonduxBatchMinter} from "contracts/KonduxBatchMinter.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title DeployBeaconFactoryFreshScript
 * @notice Fresh deployment of beacon proxy system (for testnets without existing beacon)
 * 
 * This script:
 * 1. Deploys a new KonduxImplementation
 * 2. Deploys a new UpgradeableBeacon pointing to the implementation
 * 3. Deploys a new KonduxBeaconFactory
 * 4. Optionally deploys a test clone with splitter
 * 5. Optionally deploys a BatchMinter for the test clone
 *
 * Environment variables:
 *   Required:
 *   - DEPLOYER_PK: Deployer private key
 *   - SEPOLIA_RPC_URL or RPC_URL: RPC endpoint
 *   
 *   Optional:
 *   - DRY_RUN: Set to "true" to run on fork without broadcasting (default: true)
 *   - DEPLOY_TEST_CLONE: Set to "true" to deploy a test clone (default: true)
 *   - DEPLOY_BATCH_MINTER: Set to "true" to deploy BatchMinter (default: true)
 *   - PUBLIC_DEPLOYMENT: true/false for public clone deployment
 *   - CLONE_DEPLOYER: Address to grant CLONE_DEPLOYER_ROLE
 *   - FEE_ADMIN: Address to grant FEE_ADMIN_ROLE
 *   - BATCH_MINTER_SIGNER: Address to grant BATCH_MINTER_ROLE
 *   - TEST_NAME, TEST_SYMBOL, TEST_MAX_SUPPLY: Test clone config
 *
 * Usage:
 *   # Dry run on Sepolia fork
 *   forge script scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL -vvv
 *
 *   # Actual deployment
 *   DRY_RUN=false forge script scripts/solidity/deploy/DeployBeaconFactoryFresh.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL --broadcast -vvv
 */
contract DeployBeaconFactoryFreshScript is Script {
    // Sepolia addresses
    address constant SEPOLIA_AUTHORITY = 0x685a13093cA561F531c93185B942a3f33385e14E;
    
    // Mainnet addresses (for reference/fallback)
    address constant MAINNET_AUTHORITY = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
    
    // Test clone config defaults
    string constant DEFAULT_TEST_NAME = "SepoliaTest";
    string constant DEFAULT_TEST_SYMBOL = "SEPT";
    uint256 constant DEFAULT_TEST_MAX_SUPPLY = 1000;

    struct DeployResult {
        address implementation;
        address beacon;
        address factory;
        address testClone;
        address testSplitter;
        address batchMinter;
    }

    function run() external {
        bool isDryRun = vm.envOr("DRY_RUN", true);
        bool deployTestClone = vm.envOr("DEPLOY_TEST_CLONE", true);
        bool deployBatchMinter = vm.envOr("DEPLOY_BATCH_MINTER", true);
        
        console2.log("========================================");
        console2.log("= Fresh Beacon + Factory Deployment");
        console2.log("========================================");
        console2.log("");
        
        if (isDryRun) {
            console2.log("MODE: DRY RUN (fork simulation)");
            console2.log("Set DRY_RUN=false to execute actual deployment");
        } else {
            console2.log("MODE: LIVE DEPLOYMENT");
        }
        console2.log("");

        // Get deployer
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);
        
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        console2.log("");

        // Select authority based on chain
        address authority = _selectAuthority();
        console2.log("Authority:", authority);
        console2.log("");

        DeployResult memory result;

        if (isDryRun) {
            // Dry run: use prank
            vm.deal(deployer, 10 ether);
            vm.startPrank(deployer);
            result = _executeDeployment(deployer, authority, deployTestClone, deployBatchMinter);
            vm.stopPrank();
        } else {
            // Live deployment
            vm.startBroadcast(deployerKey);
            result = _executeDeployment(deployer, authority, deployTestClone, deployBatchMinter);
            vm.stopBroadcast();
        }

        _printSummary(result, isDryRun);
        
        if (deployTestClone && result.testClone != address(0)) {
            _verifyTestClone(result);
        }
        
        if (result.batchMinter != address(0)) {
            _verifyBatchMinter(result);
        }
    }

    function _executeDeployment(
        address deployer,
        address authority,
        bool deployTestClone,
        bool deployBatchMinter
    ) internal returns (DeployResult memory result) {
        console2.log("=== Executing Deployment ===");
        
        // Step 1: Deploy new implementation
        console2.log("Step 1: Deploying KonduxImplementation...");
        result.implementation = address(new KonduxImplementation());
        console2.log("  Implementation:", result.implementation);
        
        // Step 2: Deploy beacon
        console2.log("Step 2: Deploying UpgradeableBeacon...");
        result.beacon = address(new UpgradeableBeacon(result.implementation, deployer));
        console2.log("  Beacon:", result.beacon);
        console2.log("  Beacon owner:", deployer);
        
        // Step 3: Deploy factory
        console2.log("Step 3: Deploying KonduxBeaconFactory...");
        result.factory = address(new KonduxBeaconFactory(result.implementation));
        console2.log("  Factory:", result.factory);
        
        // Configure factory
        _configureFactory(KonduxBeaconFactory(result.factory), deployer);
        
        // Step 4: Deploy test clone (optional)
        if (deployTestClone) {
            console2.log("Step 4: Deploying test clone with splitter...");
            (result.testClone, result.testSplitter) = _deployTestClone(
                KonduxBeaconFactory(result.factory),
                deployer
            );
        }
        
        // Step 5: Deploy BatchMinter (optional)
        if (deployBatchMinter && result.testClone != address(0)) {
            console2.log("Step 5: Deploying KonduxBatchMinter...");
            result.batchMinter = _deployBatchMinter(result.testClone, authority, deployer);
        }
        
        console2.log("");
    }

    function _configureFactory(KonduxBeaconFactory factory, address deployer) internal {
        bool publicDeployment = vm.envOr("PUBLIC_DEPLOYMENT", false);
        
        if (!publicDeployment) {
            factory.setPublicDeployment(false);
            console2.log("  Public deployment: disabled");
        } else {
            console2.log("  Public deployment: enabled");
        }
        
        // Grant CLONE_DEPLOYER_ROLE
        if (vm.envExists("CLONE_DEPLOYER")) {
            address cloneDeployer = vm.envAddress("CLONE_DEPLOYER");
            factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), cloneDeployer);
            console2.log("  CLONE_DEPLOYER_ROLE granted to:", cloneDeployer);
        } else if (!publicDeployment) {
            factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), deployer);
            console2.log("  CLONE_DEPLOYER_ROLE granted to deployer");
        }
        
        // Grant FEE_ADMIN_ROLE
        if (vm.envExists("FEE_ADMIN")) {
            address feeAdmin = vm.envAddress("FEE_ADMIN");
            if (feeAdmin != deployer) {
                factory.grantRole(factory.FEE_ADMIN_ROLE(), feeAdmin);
                console2.log("  FEE_ADMIN_ROLE granted to:", feeAdmin);
            } else {
                console2.log("  FEE_ADMIN_ROLE: deployer already has it");
            }
        } else {
            console2.log("  FEE_ADMIN_ROLE: deployer (default)");
        }
    }

    function _deployTestClone(
        KonduxBeaconFactory factory,
        address admin
    ) internal returns (address clone, address splitter) {
        string memory testName = vm.envOr("TEST_NAME", DEFAULT_TEST_NAME);
        string memory testSymbol = vm.envOr("TEST_SYMBOL", DEFAULT_TEST_SYMBOL);
        uint256 testMaxSupply = vm.envOr("TEST_MAX_SUPPLY", DEFAULT_TEST_MAX_SUPPLY);
        
        (clone, splitter) = factory.deployCloneWithSplitter(
            testName,
            testSymbol,
            testMaxSupply,
            admin,              // initialAdmin
            true,               // deploySplitter
            address(0),         // partnerWallet (none for test)
            500,                // manufacturerCutBP (5%)
            0,                  // partnerCutBP (0%)
            500,                // defaultCreatorCutBP (5%)
            admin               // defaultCreatorWallet
        );
        
        console2.log("  Test clone:", clone);
        console2.log("  Test splitter:", splitter);
    }

    function _deployBatchMinter(
        address targetClone,
        address authority,
        address admin
    ) internal returns (address batchMinter) {
        batchMinter = address(new KonduxBatchMinter(
            targetClone,
            authority
        ));
        console2.log("  BatchMinter deployed:", batchMinter);
        console2.log("  Target clone:", targetClone);
        console2.log("  Authority:", authority);
        
        // Grant MINTER_ROLE on the clone to the BatchMinter
        KonduxImplementation clone = KonduxImplementation(payable(targetClone));
        bytes32 MINTER_ROLE = clone.MINTER_ROLE();
        clone.grantRole(MINTER_ROLE, batchMinter);
        console2.log("  MINTER_ROLE granted to BatchMinter on clone");
        
        // Configure BatchMinter roles
        KonduxBatchMinter minter = KonduxBatchMinter(batchMinter);
        
        if (vm.envExists("BATCH_MINTER_SIGNER")) {
            address signer = vm.envAddress("BATCH_MINTER_SIGNER");
            minter.grantRole(minter.BATCH_MINTER_ROLE(), signer);
            console2.log("  BATCH_MINTER_ROLE granted to:", signer);
        } else {
            minter.grantRole(minter.BATCH_MINTER_ROLE(), admin);
            console2.log("  BATCH_MINTER_ROLE granted to admin");
        }
    }

    function _verifyTestClone(DeployResult memory result) internal view {
        console2.log("=== Verifying Test Clone ===");
        
        KonduxImplementation clone = KonduxImplementation(payable(result.testClone));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(result.testSplitter));
        
        console2.log("Clone name:", clone.name());
        console2.log("Clone symbol:", clone.symbol());
        console2.log("Clone maxSupply:", clone.maxSupply());
        
        // KEY VERIFICATION: royaltyInfo returns splitter
        (address royaltyReceiver, uint256 royaltyAmount) = clone.royaltyInfo(1, 10000);
        console2.log("");
        console2.log("=== CRITICAL VERIFICATION ===");
        console2.log("royaltyInfo() receiver:", royaltyReceiver);
        console2.log("Expected (splitter):", result.testSplitter);
        
        if (royaltyReceiver == result.testSplitter) {
            console2.log("SUCCESS: royaltyInfo() correctly returns splitter address!");
        } else {
            console2.log("FAILURE: royaltyInfo() does NOT return splitter!");
        }
        
        console2.log("Royalty amount (BP):", royaltyAmount);
        console2.log("");
        
        // Splitter verification
        console2.log("Splitter collection:", splitter.collection());
        console2.log("Splitter manufacturerCutBP:", splitter.manufacturerCutBP());
        console2.log("Splitter partnerCutBP:", splitter.partnerCutBP());
        console2.log("Splitter defaultCreatorCutBP:", splitter.defaultCreatorCutBP());
        
        console2.log("Clone's royaltySplitter storage:", clone.royaltySplitter());
        
        // Verify splitter has COLLECTION_ROLE for clone
        bytes32 COLLECTION_ROLE = splitter.COLLECTION_ROLE();
        bool cloneHasCollectionRole = splitter.hasRole(COLLECTION_ROLE, result.testClone);
        console2.log("Clone has COLLECTION_ROLE on splitter:", cloneHasCollectionRole);
        
        if (!cloneHasCollectionRole) {
            console2.log("WARNING: Clone cannot distribute royalties via splitter!");
        }
        
        console2.log("");
    }

    function _verifyBatchMinter(DeployResult memory result) internal view {
        console2.log("=== Verifying BatchMinter ===");
        
        KonduxBatchMinter minter = KonduxBatchMinter(result.batchMinter);
        KonduxImplementation clone = KonduxImplementation(payable(result.testClone));
        
        address target = address(minter.kondux());
        console2.log("BatchMinter target (kondux):", target);
        console2.log("Expected (testClone):", result.testClone);
        
        if (target == result.testClone) {
            console2.log("SUCCESS: BatchMinter correctly targets test clone!");
        } else {
            console2.log("FAILURE: BatchMinter target mismatch!");
        }
        
        bytes32 MINTER_ROLE = clone.MINTER_ROLE();
        bool hasMinterRole = clone.hasRole(MINTER_ROLE, result.batchMinter);
        console2.log("BatchMinter has MINTER_ROLE on clone:", hasMinterRole);
        
        if (!hasMinterRole) {
            console2.log("WARNING: BatchMinter cannot mint on clone!");
        }
        
        console2.log("BatchMinter paused:", minter.paused());
        console2.log("");
    }

    function _printSummary(DeployResult memory result, bool isDryRun) internal view {
        console2.log("========================================");
        console2.log("= DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("");
        
        if (isDryRun) {
            console2.log("STATUS: DRY RUN COMPLETE (no actual transactions)");
            console2.log("");
        }
        
        console2.log("Implementation:", result.implementation);
        console2.log("Beacon:", result.beacon);
        console2.log("Factory:", result.factory);
        
        if (result.testClone != address(0)) {
            console2.log("");
            console2.log("Test Clone:", result.testClone);
            console2.log("Test Splitter:", result.testSplitter);
            if (result.batchMinter != address(0)) {
                console2.log("BatchMinter:", result.batchMinter);
            }
        }
        
        console2.log("");
        console2.log("========================================");
        console2.log("= NEXT STEPS");
        console2.log("========================================");
        
        if (isDryRun) {
            console2.log("1. Review the dry run output above");
            console2.log("2. If everything looks correct, run with DRY_RUN=false");
            console2.log("3. After deployment, verify contracts on Etherscan");
            console2.log("4. Update address-book.json with new addresses");
        } else {
            console2.log("1. Verify contracts on Etherscan:");
            console2.log("   forge verify-contract <address> <contract> --chain sepolia");
            console2.log("2. Update historical-addresses.json");
            console2.log("3. Test minting via BatchMinter");
            console2.log("4. Test listing on OpenSea testnets");
        }
        
        console2.log("");
    }

    function _selectPrivateKey() internal view returns (uint256) {
        if (vm.envExists("PROD_DEPLOYER_PK")) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        return vm.envUint("DEPLOYER_PK");
    }

    function _selectAuthority() internal view returns (address) {
        // Allow override via env var
        if (vm.envExists("AUTHORITY")) {
            return vm.envAddress("AUTHORITY");
        }
        
        // Select based on chain ID
        if (block.chainid == 11155111) {
            return SEPOLIA_AUTHORITY;
        } else if (block.chainid == 1) {
            return MAINNET_AUTHORITY;
        }
        
        // Default to Sepolia for unknown chains (likely local fork)
        return SEPOLIA_AUTHORITY;
    }
}
