// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";
import {KonduxRoyaltySplitter} from "contracts/KonduxRoyaltySplitter.sol";
import {IKonduxRoyaltySplitter} from "contracts/interfaces/IKonduxRoyaltySplitter.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title UpgradeBeaconAndDeployFactoryScript
 * @notice Option B: Upgrade existing beacon implementation + deploy new factory
 * 
 * This script:
 * 1. Deploys a new KonduxImplementation with updated initialize() signature
 * 2. Upgrades the existing beacon to point to the new implementation
 * 3. Deploys a new KonduxBeaconFactory with updated deployCloneWithSplitter()
 * 4. Optionally deploys a test clone to verify the new flow works
 *
 * Environment variables:
 *   Required:
 *   - PROD_DEPLOYER_PK or DEPLOYER_PK: Deployer private key
 *   - OLD_BEACON: Address of existing UpgradeableBeacon to upgrade
 *   
 *   Optional:
 *   - DRY_RUN: Set to "true" to run on mainnet fork without broadcasting (default: true)
 *   - DEPLOY_TEST_CLONE: Set to "true" to deploy a test clone after factory deployment
 *   - PUBLIC_DEPLOYMENT: true/false for public clone deployment on new factory
 *   - CLONE_DEPLOYER: Address to grant CLONE_DEPLOYER_ROLE
 *   - FEE_ADMIN: Address to grant FEE_ADMIN_ROLE
 *
 * Usage:
 *   # Dry run on mainnet fork (default)
 *   forge script scripts/solidity/deploy/UpgradeBeaconAndDeployFactory.s.sol \
 *     --rpc-url $MAINNET_RPC_URL -vvv
 *
 *   # Actual deployment
 *   DRY_RUN=false forge script scripts/solidity/deploy/UpgradeBeaconAndDeployFactory.s.sol \
 *     --rpc-url $MAINNET_RPC_URL --broadcast -vvv
 */
contract UpgradeBeaconAndDeployFactoryScript is Script {
    // Mainnet addresses
    address constant OLD_FACTORY = 0xa265a01205f304F2652277AaC924AB56D2e0Cf77;
    address constant OLD_BEACON = 0x21D1a52A17a1Df346Dd223Ef89D0e362Ee64b219;
    address constant CURRENT_IMPL = 0xd5E8Ac6284825D99dAE3d16Bef4537d4B665E1Be;
    address constant FACTORY_ADMIN = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    
    // Test clone config (for dry run verification)
    string constant TEST_NAME = "DryRunTest";
    string constant TEST_SYMBOL = "DRT";
    uint256 constant TEST_MAX_SUPPLY = 100;

    struct DeployResult {
        address newImplementation;
        address newFactory;
        address testClone;
        address testSplitter;
    }

    function run() external {
        bool isDryRun = vm.envOr("DRY_RUN", true);
        bool deployTestClone = vm.envOr("DEPLOY_TEST_CLONE", true);
        
        console2.log("========================================");
        console2.log("= Option B: Upgrade Beacon + New Factory");
        console2.log("========================================");
        console2.log("");
        
        if (isDryRun) {
            console2.log("MODE: DRY RUN (mainnet fork simulation)");
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

        // Verify existing contracts
        _verifyExistingState(deployer);

        DeployResult memory result;

        if (isDryRun) {
            // Dry run: impersonate beacon owner and execute
            result = _executeDryRun(deployer, deployTestClone);
        } else {
            // Live deployment
            vm.startBroadcast(deployerKey);
            result = _executeDeployment(deployer, deployTestClone);
            vm.stopBroadcast();
        }

        _printSummary(result, isDryRun);
        
        if (deployTestClone && result.testClone != address(0)) {
            _verifyTestClone(result);
        }
    }

    function _verifyExistingState(address deployer) internal view {
        console2.log("=== Verifying Existing State ===");
        
        // Check beacon exists and get current implementation
        UpgradeableBeacon beacon = UpgradeableBeacon(OLD_BEACON);
        address currentImpl = beacon.implementation();
        address beaconOwner = beacon.owner();
        
        console2.log("Old Beacon:", OLD_BEACON);
        console2.log("  Current implementation:", currentImpl);
        console2.log("  Beacon owner:", beaconOwner);
        
        if (currentImpl != CURRENT_IMPL) {
            console2.log("  WARNING: Current impl differs from expected!");
            console2.log("  Expected:", CURRENT_IMPL);
        }
        
        // Check if deployer can upgrade beacon
        if (beaconOwner != deployer && beaconOwner != OLD_FACTORY) {
            console2.log("  WARNING: Deployer is not beacon owner!");
            console2.log("  Beacon owner:", beaconOwner);
            console2.log("  You may need to use the factory to upgrade.");
        }
        
        console2.log("Old Factory:", OLD_FACTORY);
        console2.log("");
    }

    function _executeDryRun(address deployer, bool deployTestClone) internal returns (DeployResult memory result) {
        console2.log("=== Executing Dry Run ===");
        
        // For dry run, we impersonate the actual factory admin
        address admin = FACTORY_ADMIN;
        console2.log("Impersonating factory admin:", admin);
        
        // Give admin some ETH for gas
        vm.deal(admin, 10 ether);
        
        // Step 1: Deploy new implementation
        console2.log("Step 1: Deploying new KonduxImplementation...");
        vm.startPrank(admin);
        result.newImplementation = address(new KonduxImplementation());
        console2.log("  New implementation:", result.newImplementation);
        vm.stopPrank();
        
        // Step 2: Upgrade beacon (factory owns beacon, admin has DEFAULT_ADMIN_ROLE on factory)
        console2.log("Step 2: Upgrading beacon to new implementation...");
        console2.log("  Beacon owned by factory, using factory.upgradeImplementation()");
        vm.startPrank(admin);
        KonduxBeaconFactory(OLD_FACTORY).upgradeImplementation(result.newImplementation);
        console2.log("  Beacon upgraded successfully");
        console2.log("  New implementation:", UpgradeableBeacon(OLD_BEACON).implementation());
        vm.stopPrank();
        
        // Step 3: Deploy new factory
        console2.log("Step 3: Deploying new KonduxBeaconFactory...");
        vm.startPrank(admin);
        result.newFactory = address(new KonduxBeaconFactory(result.newImplementation));
        console2.log("  New factory:", result.newFactory);
        
        // Configure factory
        _configureFactory(KonduxBeaconFactory(result.newFactory), admin);
        vm.stopPrank();
        
        // Step 4: Deploy test clone (optional)
        if (deployTestClone) {
            console2.log("Step 4: Deploying test clone with splitter...");
            vm.startPrank(admin);
            (result.testClone, result.testSplitter) = _deployTestClone(
                KonduxBeaconFactory(result.newFactory),
                admin
            );
            vm.stopPrank();
        }
        
        console2.log("");
    }

    function _executeDeployment(address deployer, bool deployTestClone) internal returns (DeployResult memory result) {
        console2.log("=== Executing Live Deployment ===");
        
        // Step 1: Deploy new implementation
        console2.log("Step 1: Deploying new KonduxImplementation...");
        result.newImplementation = address(new KonduxImplementation());
        console2.log("  New implementation:", result.newImplementation);
        
        // Step 2: Upgrade beacon
        console2.log("Step 2: Upgrading beacon to new implementation...");
        UpgradeableBeacon beacon = UpgradeableBeacon(OLD_BEACON);
        address beaconOwner = beacon.owner();
        
        if (beaconOwner == OLD_FACTORY) {
            KonduxBeaconFactory(OLD_FACTORY).upgradeImplementation(result.newImplementation);
        } else {
            beacon.upgradeTo(result.newImplementation);
        }
        console2.log("  Beacon upgraded");
        
        // Step 3: Deploy new factory
        console2.log("Step 3: Deploying new KonduxBeaconFactory...");
        result.newFactory = address(new KonduxBeaconFactory(result.newImplementation));
        console2.log("  New factory:", result.newFactory);
        
        _configureFactory(KonduxBeaconFactory(result.newFactory), deployer);
        
        // Step 4: Deploy test clone (optional)
        if (deployTestClone) {
            console2.log("Step 4: Deploying test clone with splitter...");
            (result.testClone, result.testSplitter) = _deployTestClone(
                KonduxBeaconFactory(result.newFactory),
                deployer
            );
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
            }
        }
    }

    function _deployTestClone(
        KonduxBeaconFactory factory,
        address admin
    ) internal returns (address clone, address splitter) {
        (clone, splitter) = factory.deployCloneWithSplitter(
            TEST_NAME,
            TEST_SYMBOL,
            TEST_MAX_SUPPLY,
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

    function _verifyTestClone(DeployResult memory result) internal view {
        console2.log("=== Verifying Test Clone ===");
        
        KonduxImplementation clone = KonduxImplementation(payable(result.testClone));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(result.testSplitter));
        
        // Basic info
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
            console2.log("This indicates the fix did not work as expected.");
        }
        
        console2.log("Royalty amount (BP):", royaltyAmount);
        console2.log("");
        
        // Splitter verification
        console2.log("Splitter collection:", splitter.collection());
        console2.log("Splitter manufacturerCutBP:", splitter.manufacturerCutBP());
        console2.log("Splitter partnerCutBP:", splitter.partnerCutBP());
        console2.log("Splitter defaultCreatorCutBP:", splitter.defaultCreatorCutBP());
        
        // Clone's royaltySplitter storage
        console2.log("Clone's royaltySplitter storage:", clone.royaltySplitter());
        
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
        
        console2.log("New Implementation:", result.newImplementation);
        console2.log("New Factory:", result.newFactory);
        console2.log("Old Beacon (upgraded):", OLD_BEACON);
        console2.log("Old Factory (deprecated):", OLD_FACTORY);
        
        if (result.testClone != address(0)) {
            console2.log("");
            console2.log("Test Clone:", result.testClone);
            console2.log("Test Splitter:", result.testSplitter);
        }
        
        console2.log("");
        console2.log("========================================");
        console2.log("= NEXT STEPS");
        console2.log("========================================");
        
        if (isDryRun) {
            console2.log("1. Review the dry run output above");
            console2.log("2. If everything looks correct, run with DRY_RUN=false");
            console2.log("3. After deployment, verify contracts on Etherscan");
            console2.log("4. Update frontend/backend to use new factory address");
        } else {
            console2.log("1. Verify new contracts on Etherscan");
            console2.log("2. Update frontend/backend to use new factory:", result.newFactory);
            console2.log("3. Old factory is now deprecated (wrong function signatures)");
            console2.log("4. Existing clones continue working (upgraded via beacon)");
        }
        
        console2.log("");
    }

    function _selectPrivateKey() internal view returns (uint256) {
        if (vm.envExists("PROD_DEPLOYER_PK")) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        return vm.envUint("DEPLOYER_PK");
    }
}
