// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";
import {KonduxRoyaltySplitter} from "contracts/KonduxRoyaltySplitter.sol";
import {IKonduxRoyaltySplitter} from "contracts/interfaces/IKonduxRoyaltySplitter.sol";
import {KonduxBatchMinter} from "contracts/KonduxBatchMinter.sol";
import {IAuthority} from "contracts/interfaces/IAuthority.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ICreatorTokenTransferValidator} from "contracts/interfaces/ICreatorTokenTransferValidator.sol";

/**
 * @title UpgradeBeaconAndDeployFactoryScript
 * @notice Option B: Upgrade existing beacon implementation + deploy new factory
 * 
 * This script:
 * 1. Deploys a new KonduxImplementation with updated initialize() signature
 * 2. Upgrades the existing beacon to point to the new implementation
 * 3. Deploys a new KonduxBeaconFactory with updated deployCloneWithSplitter()
 * 4. Optionally deploys a clone with splitter and BatchMinter
 *
 * Environment variables:
 *   Required:
 *   - PROD_DEPLOYER_PK or DEPLOYER_PK: Deployer private key
 *   
 *   Optional:
 *   - DRY_RUN: Set to "true" to run on mainnet fork without broadcasting (default: true)
 *   - DEPLOY_TEST_CLONE: Set to "true" to deploy a clone after factory deployment
 *   - DEPLOY_BATCH_MINTER: Set to "true" to deploy a new BatchMinter for the clone
 *   - PUBLIC_DEPLOYMENT: true/false for public clone deployment on new factory
 *   - CLONE_DEPLOYER: Address to grant CLONE_DEPLOYER_ROLE
 *   - FEE_ADMIN: Address to grant FEE_ADMIN_ROLE
 *   - BATCH_MINTER_SIGNER: Address to grant BATCH_MINTER_ROLE on the BatchMinter
 *
 * Clone Configuration (env vars):
 *   - CLONE_NAME: Name for the clone (default: "Kondux Omniforge")
 *   - CLONE_SYMBOL: Symbol for the clone (default: "CRTR")
 *   - CLONE_MAX_SUPPLY: Max supply (default: 100000)
 *   - CLONE_ADMIN: Admin address for the clone
 *   - MANUFACTURER_WALLET: Wallet for manufacturer royalty cut
 *   - CREATOR_WALLET: Wallet for default creator royalty cut
 *   - MANUFACTURER_CUT_BP: Manufacturer cut in basis points (default: 500 = 5%)
 *   - CREATOR_CUT_BP: Creator cut in basis points (default: 500 = 5%)
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
    address constant AUTHORITY = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
    address constant OLD_BATCH_MINTER = 0xa14Fe1Ac05537Ae49B5f75876Fc86aAe67BA46BF;
    
    // Limit Break Transfer Validator V3
    address constant TRANSFER_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    uint48 constant WHITELIST_ID = 16; // Pre-existing OpenSea-compatible whitelist
    
    // Clone config defaults for Kondux Omniforge
    string constant DEFAULT_CLONE_NAME = "Kondux Omniforge";
    string constant DEFAULT_CLONE_SYMBOL = "CRTR";
    uint256 constant DEFAULT_CLONE_MAX_SUPPLY = 100000;
    address constant DEFAULT_ROYALTY_WALLET = 0x3493c35A1890A758F21D74B757F051702f1dE82D;
    uint256 constant DEFAULT_MANUFACTURER_CUT_BP = 500; // 5%
    uint256 constant DEFAULT_CREATOR_CUT_BP = 500; // 5%
    
    // Base URI template (clone address will be appended)
    string constant BASE_URI_PREFIX = "https://toixbmwexblvs2o2rnl3kk63oi0hmvtm.lambda-url.us-east-1.on.aws/api/v1/metadata/";

    struct DeployResult {
        address newImplementation;
        address newFactory;
        address clone;
        address splitter;
        address batchMinter;
    }

    function run() external {
        bool isDryRun = vm.envOr("DRY_RUN", true);
        bool deployClone = vm.envOr("DEPLOY_TEST_CLONE", true);
        bool deployBatchMinter = vm.envOr("DEPLOY_BATCH_MINTER", true);
        
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
            result = _executeDryRun(deployer, deployClone, deployBatchMinter);
        } else {
            // Live deployment
            vm.startBroadcast(deployerKey);
            result = _executeDeployment(deployer, deployClone, deployBatchMinter);
            vm.stopBroadcast();
        }

        _printSummary(result, isDryRun);
        
        if (deployClone && result.clone != address(0)) {
            _verifyClone(result);
        }
        
        if (result.batchMinter != address(0)) {
            _verifyBatchMinter(result);
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

    function _executeDryRun(address deployer, bool deployClone, bool deployBatchMinter) internal returns (DeployResult memory result) {
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
        
        // Step 4: Deploy clone with splitter (optional)
        if (deployClone) {
            console2.log("Step 4: Deploying Kondux Omniforge clone with splitter...");
            vm.startPrank(admin);
            (result.clone, result.splitter) = _deployClone(
                KonduxBeaconFactory(result.newFactory),
                admin
            );
            
            // Step 4b: Configure marketplace security with existing whitelist ID 16
            _configureMarketplaceSecurity(result.clone);
            
            // Step 4c: Set base URI with actual clone address
            _setBaseURI(result.clone);
            vm.stopPrank();
        }
        
        // Step 5: Deploy BatchMinter (optional)
        if (deployBatchMinter && result.clone != address(0)) {
            console2.log("Step 5: Deploying KonduxBatchMinter for clone...");
            vm.startPrank(admin);
            result.batchMinter = _deployBatchMinter(result.clone, admin);
            vm.stopPrank();
        }
        
        console2.log("");
    }

    function _executeDeployment(address deployer, bool deployClone, bool deployBatchMinter) internal returns (DeployResult memory result) {
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
        
        // Step 4: Deploy clone with splitter (optional)
        if (deployClone) {
            console2.log("Step 4: Deploying Kondux Omniforge clone with splitter...");
            (result.clone, result.splitter) = _deployClone(
                KonduxBeaconFactory(result.newFactory),
                deployer
            );
            
            // Step 4b: Configure marketplace security with existing whitelist ID 16
            _configureMarketplaceSecurity(result.clone);
            
            // Step 4c: Set base URI with actual clone address
            _setBaseURI(result.clone);
        }
        
        // Step 5: Deploy BatchMinter (optional)
        if (deployBatchMinter && result.clone != address(0)) {
            console2.log("Step 5: Deploying KonduxBatchMinter for clone...");
            result.batchMinter = _deployBatchMinter(result.clone, deployer);
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

    function _deployClone(
        KonduxBeaconFactory factory,
        address admin
    ) internal returns (address clone, address splitter) {
        // Get clone configuration from env vars or use defaults
        string memory cloneName = vm.envOr("CLONE_NAME", DEFAULT_CLONE_NAME);
        string memory cloneSymbol = vm.envOr("CLONE_SYMBOL", DEFAULT_CLONE_SYMBOL);
        uint256 cloneMaxSupply = vm.envOr("CLONE_MAX_SUPPLY", DEFAULT_CLONE_MAX_SUPPLY);
        
        // Royalty configuration
        address manufacturerWallet = vm.envOr("MANUFACTURER_WALLET", DEFAULT_ROYALTY_WALLET);
        address creatorWallet = vm.envOr("CREATOR_WALLET", DEFAULT_ROYALTY_WALLET);
        uint96 manufacturerCutBP = uint96(vm.envOr("MANUFACTURER_CUT_BP", DEFAULT_MANUFACTURER_CUT_BP));
        uint96 creatorCutBP = uint96(vm.envOr("CREATOR_CUT_BP", DEFAULT_CREATOR_CUT_BP));
        
        // Clone admin (uses FACTORY_ADMIN by default for the DEFAULT_ADMIN_ROLE)
        address cloneAdmin = vm.envOr("CLONE_ADMIN", FACTORY_ADMIN);
        
        console2.log("  Clone config:");
        console2.log("    Name:", cloneName);
        console2.log("    Symbol:", cloneSymbol);
        console2.log("    Max Supply:", cloneMaxSupply);
        console2.log("    Admin:", cloneAdmin);
        console2.log("    Manufacturer Wallet:", manufacturerWallet);
        console2.log("    Creator Wallet:", creatorWallet);
        console2.log("    Total Royalty (BP):", manufacturerCutBP + creatorCutBP);
        
        (clone, splitter) = factory.deployCloneWithSplitter(
            cloneName,
            cloneSymbol,
            cloneMaxSupply,
            cloneAdmin,           // initialAdmin (gets DEFAULT_ADMIN_ROLE)
            true,                 // deploySplitter
            address(0),           // partnerWallet (none)
            manufacturerCutBP,    // manufacturerCutBP (5%)
            0,                    // partnerCutBP (0%)
            creatorCutBP,         // defaultCreatorCutBP (5%)
            creatorWallet         // defaultCreatorWallet
        );
        
        console2.log("  Clone deployed:", clone);
        console2.log("  Splitter deployed:", splitter);
        
        // Grant MINTER_ROLE to the admin as well (in addition to factory's temp setup)
        KonduxImplementation cloneContract = KonduxImplementation(payable(clone));
        bytes32 MINTER_ROLE = cloneContract.MINTER_ROLE();
        
        // Grant MINTER_ROLE to admin
        cloneContract.grantRole(MINTER_ROLE, cloneAdmin);
        console2.log("  MINTER_ROLE granted to admin:", cloneAdmin);
    }

    /**
     * @notice Configure marketplace security using Limit Break's existing whitelist ID 16
     * @dev Uses applyListToCollection instead of creating a new whitelist
     */
    function _configureMarketplaceSecurity(address clone) internal {
        console2.log("  Configuring marketplace security...");
        console2.log("    Transfer Validator:", TRANSFER_VALIDATOR);
        console2.log("    Using existing Whitelist ID:", WHITELIST_ID);
        
        ICreatorTokenTransferValidator validator = ICreatorTokenTransferValidator(TRANSFER_VALIDATOR);
        
        // Apply the existing whitelist ID 16 to this collection
        validator.applyListToCollection(clone, WHITELIST_ID);
        console2.log("    Applied whitelist ID 16 to collection");
        
        // Verify the configuration
        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy = validator.getCollectionSecurityPolicy(clone);
        console2.log("    Verified whitelist ID:", policy.listId);
        
        if (policy.listId == WHITELIST_ID) {
            console2.log("    SUCCESS: Whitelist ID 16 applied correctly!");
        } else {
            console2.log("    WARNING: Whitelist ID mismatch!");
        }
    }

    /**
     * @notice Set the base URI for the clone with the actual deployed address
     */
    function _setBaseURI(address clone) internal {
        // Convert address to string for URI
        string memory cloneAddressStr = vm.toString(clone);
        string memory baseURI = string.concat(BASE_URI_PREFIX, cloneAddressStr, "/");
        
        console2.log("  Setting base URI...");
        console2.log("    Base URI:", baseURI);
        
        KonduxImplementation cloneContract = KonduxImplementation(payable(clone));
        cloneContract.setBaseURI(baseURI);
        console2.log("    Base URI set successfully");
    }

    function _deployBatchMinter(
        address targetClone,
        address admin
    ) internal returns (address batchMinter) {
        // Deploy BatchMinter pointing to the clone
        batchMinter = address(new KonduxBatchMinter(
            targetClone,
            AUTHORITY
        ));
        console2.log("  BatchMinter deployed:", batchMinter);
        console2.log("  Target clone:", targetClone);
        
        // Grant MINTER_ROLE on the clone to the BatchMinter
        KonduxImplementation clone = KonduxImplementation(payable(targetClone));
        bytes32 MINTER_ROLE = clone.MINTER_ROLE();
        clone.grantRole(MINTER_ROLE, batchMinter);
        console2.log("  MINTER_ROLE granted to BatchMinter on clone");
        
        // Configure BatchMinter roles
        KonduxBatchMinter minter = KonduxBatchMinter(batchMinter);
        
        // Grant BATCH_MINTER_ROLE to signer if specified
        if (vm.envExists("BATCH_MINTER_SIGNER")) {
            address signer = vm.envAddress("BATCH_MINTER_SIGNER");
            minter.grantRole(minter.BATCH_MINTER_ROLE(), signer);
            console2.log("  BATCH_MINTER_ROLE granted to:", signer);
        } else {
            // Default: grant to admin
            minter.grantRole(minter.BATCH_MINTER_ROLE(), admin);
            console2.log("  BATCH_MINTER_ROLE granted to admin");
        }
    }

    function _verifyClone(DeployResult memory result) internal view {
        console2.log("=== Verifying Clone ===");
        
        KonduxImplementation clone = KonduxImplementation(payable(result.clone));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(result.splitter));
        
        // Basic info
        console2.log("Clone name:", clone.name());
        console2.log("Clone symbol:", clone.symbol());
        console2.log("Clone maxSupply:", clone.maxSupply());
        console2.log("Clone baseURI:", clone.baseURI());
        
        // KEY VERIFICATION: royaltyInfo returns splitter
        (address royaltyReceiver, uint256 royaltyAmount) = clone.royaltyInfo(1, 10000);
        console2.log("");
        console2.log("=== CRITICAL VERIFICATION ===");
        console2.log("royaltyInfo() receiver:", royaltyReceiver);
        console2.log("Expected (splitter):", result.splitter);
        
        if (royaltyReceiver == result.splitter) {
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
        
        // Verify splitter has COLLECTION_ROLE for clone
        bytes32 COLLECTION_ROLE = splitter.COLLECTION_ROLE();
        bool cloneHasCollectionRole = splitter.hasRole(COLLECTION_ROLE, result.clone);
        console2.log("Clone has COLLECTION_ROLE on splitter:", cloneHasCollectionRole);
        
        if (!cloneHasCollectionRole) {
            console2.log("WARNING: Clone cannot distribute royalties via splitter!");
        }
        
        // Verify marketplace security
        console2.log("");
        console2.log("=== Marketplace Security Verification ===");
        ICreatorTokenTransferValidator validator = ICreatorTokenTransferValidator(TRANSFER_VALIDATOR);
        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy = validator.getCollectionSecurityPolicy(result.clone);
        console2.log("Collection whitelist ID:", policy.listId);
        console2.log("Expected whitelist ID:", WHITELIST_ID);
        
        if (policy.listId == WHITELIST_ID) {
            console2.log("SUCCESS: Using Limit Break whitelist ID 16!");
        } else {
            console2.log("WARNING: Whitelist ID mismatch!");
        }
        
        console2.log("");
    }

    function _verifyBatchMinter(DeployResult memory result) internal view {
        console2.log("=== Verifying BatchMinter ===");
        
        KonduxBatchMinter minter = KonduxBatchMinter(result.batchMinter);
        KonduxImplementation clone = KonduxImplementation(payable(result.clone));
        
        // Verify target
        address target = address(minter.kondux());
        console2.log("BatchMinter target (kondux):", target);
        console2.log("Expected (clone):", result.clone);
        
        if (target == result.clone) {
            console2.log("SUCCESS: BatchMinter correctly targets clone!");
        } else {
            console2.log("FAILURE: BatchMinter target mismatch!");
        }
        
        // Verify MINTER_ROLE
        bytes32 MINTER_ROLE = clone.MINTER_ROLE();
        bool hasMinterRole = clone.hasRole(MINTER_ROLE, result.batchMinter);
        console2.log("BatchMinter has MINTER_ROLE on clone:", hasMinterRole);
        
        if (!hasMinterRole) {
            console2.log("WARNING: BatchMinter cannot mint on clone!");
        }
        
        // List all addresses with MINTER_ROLE
        console2.log("");
        console2.log("MINTER_ROLE holders:");
        console2.log("  - BatchMinter:", result.batchMinter, "->", hasMinterRole);
        bool adminHasMinterRole = clone.hasRole(MINTER_ROLE, FACTORY_ADMIN);
        console2.log("  - Admin:", FACTORY_ADMIN, "->", adminHasMinterRole);
        
        // Check pause state
        console2.log("");
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
        
        console2.log("New Implementation:", result.newImplementation);
        console2.log("New Factory:", result.newFactory);
        console2.log("Old Beacon (upgraded):", OLD_BEACON);
        console2.log("Old Factory (deprecated):", OLD_FACTORY);
        
        if (result.clone != address(0)) {
            console2.log("");
            console2.log("=== Kondux Omniforge Clone ===");
            console2.log("Clone:", result.clone);
            console2.log("Splitter (Royalty Receiver):", result.splitter);
            if (result.batchMinter != address(0)) {
                console2.log("BatchMinter:", result.batchMinter);
            }
        }
        
        console2.log("");
        console2.log("========================================");
        console2.log("= CONFIGURATION APPLIED");
        console2.log("========================================");
        console2.log("Transfer Validator: 0x721C008fdff27BF06E7E123956E2Fe03B63342e3 (Limit Break V3)");
        console2.log("Security Level: 4 (Whitelisted operators only)");
        console2.log("Operator Whitelist ID: 16");
        console2.log("Royalty: 10% (1000 BP) via splitter");
        console2.log("  - Manufacturer: 5% (500 BP)");
        console2.log("  - Partner: 0%");
        console2.log("  - Creator: 5% (500 BP)");
        
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
