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
 * @title DeploySepoliaFreshScript
 * @notice Fresh deployment of Kondux infrastructure on Sepolia testnet
 *
 * This script:
 * 1. Deploys a new KonduxImplementation
 * 2. Deploys a new KonduxBeaconFactory (which creates its own beacon)
 * 3. Optionally deploys a clone with splitter
 * 4. Optionally deploys a BatchMinter
 *
 * Environment variables:
 *   Required:
 *   - PROD_DEPLOYER_PK or DEPLOYER_PK: Deployer private key
 *
 *   Optional:
 *   - DRY_RUN: Set to "true" to simulate without broadcasting (default: true)
 *   - DEPLOY_TEST_CLONE: Set to "true" to deploy a test clone (default: true)
 *   - DEPLOY_BATCH_MINTER: Set to "true" to deploy BatchMinter (default: true)
 *   - PUBLIC_DEPLOYMENT: true/false for public clone deployment (default: false)
 *   - SKIP_TRANSFER_VALIDATOR: Set to "true" to skip transfer validator config (default: true for Sepolia)
 *
 * Clone Configuration (env vars):
 *   - CLONE_NAME: Name for the clone (default: "Kondux Sepolia Test")
 *   - CLONE_SYMBOL: Symbol for the clone (default: "KSEP")
 *   - CLONE_MAX_SUPPLY: Max supply (default: 10000)
 *   - CLONE_ADMIN: Admin address for the clone (default: deployer)
 *   - MANUFACTURER_WALLET: Wallet for manufacturer royalty cut
 *   - CREATOR_WALLET: Wallet for default creator royalty cut
 *   - MANUFACTURER_CUT_BP: Manufacturer cut in basis points (default: 500 = 5%)
 *   - CREATOR_CUT_BP: Creator cut in basis points (default: 500 = 5%)
 *
 * Usage:
 *   # Dry run (default)
 *   forge script scripts/solidity/deploy/DeploySepoliaFresh.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL -vvv
 *
 *   # Actual deployment
 *   DRY_RUN=false forge script scripts/solidity/deploy/DeploySepoliaFresh.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvv
 */
contract DeploySepoliaFreshScript is Script {
    // Sepolia-specific addresses (some may not exist on testnet)
    // Limit Break Transfer Validator V3 - check if deployed on Sepolia
    address constant TRANSFER_VALIDATOR_MAINNET = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    // Clone config defaults for Sepolia testing
    string constant DEFAULT_CLONE_NAME = "Kondux Sepolia Test";
    string constant DEFAULT_CLONE_SYMBOL = "KSEP";
    uint256 constant DEFAULT_CLONE_MAX_SUPPLY = 10000;
    uint256 constant DEFAULT_MANUFACTURER_CUT_BP = 500; // 5%
    uint256 constant DEFAULT_CREATOR_CUT_BP = 500; // 5%

    // Base URI template (clone address will be appended)
    string constant BASE_URI_PREFIX = "https://toixbmwexblvs2o2rnl3kk63oi0hmvtm.lambda-url.us-east-1.on.aws/api/v1/metadata/";

    struct DeployResult {
        address implementation;
        address factory;
        address beacon;
        address clone;
        address splitter;
        address batchMinter;
    }

    function run() external {
        bool isDryRun = vm.envOr("DRY_RUN", true);
        bool deployClone = vm.envOr("DEPLOY_TEST_CLONE", true);
        bool deployBatchMinter = vm.envOr("DEPLOY_BATCH_MINTER", true);
        bool skipTransferValidator = vm.envOr("SKIP_TRANSFER_VALIDATOR", false);

        console2.log("========================================");
        console2.log("= Sepolia Fresh Deployment");
        console2.log("========================================");
        console2.log("");

        if (isDryRun) {
            console2.log("MODE: DRY RUN (simulation only)");
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
        console2.log("Deployer balance (ETH):", deployer.balance / 1e18);
        console2.log("");

        // Verify we're on Sepolia
        require(block.chainid == 11155111, "This script is for Sepolia only (chainId 11155111)");

        DeployResult memory result;

        if (isDryRun) {
            // Dry run: simulate deployment
            vm.startPrank(deployer);
            result = _executeDeployment(deployer, deployClone, deployBatchMinter, skipTransferValidator);
            vm.stopPrank();
        } else {
            // Live deployment
            vm.startBroadcast(deployerKey);
            result = _executeDeployment(deployer, deployClone, deployBatchMinter, skipTransferValidator);
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

    function _executeDeployment(
        address deployer,
        bool deployClone,
        bool deployBatchMinter,
        bool skipTransferValidator
    ) internal returns (DeployResult memory result) {
        console2.log("=== Executing Deployment ===");

        // Step 1: Deploy new implementation
        console2.log("Step 1: Deploying KonduxImplementation...");
        result.implementation = address(new KonduxImplementation());
        console2.log("  Implementation:", result.implementation);

        // Step 2: Deploy factory (creates its own beacon internally)
        console2.log("Step 2: Deploying KonduxBeaconFactory...");
        KonduxBeaconFactory factory = new KonduxBeaconFactory(result.implementation);
        result.factory = address(factory);
        result.beacon = address(factory.beacon());
        console2.log("  Factory:", result.factory);
        console2.log("  Beacon:", result.beacon);

        // Configure factory
        _configureFactory(factory, deployer);

        // Step 3: Deploy clone with splitter (optional)
        if (deployClone) {
            console2.log("Step 3: Deploying test clone with splitter...");
            (result.clone, result.splitter) = _deployClone(factory, deployer);

            // Step 3b: Configure marketplace security (skip on Sepolia if validator not deployed)
            if (!skipTransferValidator) {
                _configureMarketplaceSecurity(result.clone);
            } else {
                console2.log("  Skipping transfer validator config (not deployed on Sepolia)");
            }

            // Step 3c: Set base URI with actual clone address
            _setBaseURI(result.clone);
        }

        // Step 4: Deploy BatchMinter (optional)
        if (deployBatchMinter && result.clone != address(0)) {
            console2.log("Step 4: Deploying KonduxBatchMinter...");
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

        // Grant CLONE_DEPLOYER_ROLE to deployer if not public
        if (!publicDeployment) {
            factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), deployer);
            console2.log("  CLONE_DEPLOYER_ROLE granted to deployer");
        }

        console2.log("  FEE_ADMIN_ROLE: deployer (default)");
    }

    function _deployClone(
        KonduxBeaconFactory factory,
        address admin
    ) internal returns (address clone, address splitter) {
        // Get clone configuration from env vars or use defaults
        string memory cloneName = vm.envOr("CLONE_NAME", DEFAULT_CLONE_NAME);
        string memory cloneSymbol = vm.envOr("CLONE_SYMBOL", DEFAULT_CLONE_SYMBOL);
        uint256 cloneMaxSupply = vm.envOr("CLONE_MAX_SUPPLY", DEFAULT_CLONE_MAX_SUPPLY);

        // Royalty configuration - use deployer as default wallet
        address manufacturerWallet = vm.envOr("MANUFACTURER_WALLET", admin);
        address creatorWallet = vm.envOr("CREATOR_WALLET", admin);
        uint96 manufacturerCutBP = uint96(vm.envOr("MANUFACTURER_CUT_BP", DEFAULT_MANUFACTURER_CUT_BP));
        uint96 creatorCutBP = uint96(vm.envOr("CREATOR_CUT_BP", DEFAULT_CREATOR_CUT_BP));

        // Clone admin
        address cloneAdmin = vm.envOr("CLONE_ADMIN", admin);

        console2.log("  Clone config:");
        console2.log("    Name:", cloneName);
        console2.log("    Symbol:", cloneSymbol);
        console2.log("    Max Supply:", cloneMaxSupply);
        console2.log("    Admin:", cloneAdmin);
        console2.log("    Manufacturer Wallet:", manufacturerWallet);
        console2.log("    Creator Wallet:", creatorWallet);
        console2.log("    Total Royalty (BP):", uint256(manufacturerCutBP) + uint256(creatorCutBP));

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

        // Update splitter wallets if different from defaults
        if (manufacturerWallet != cloneAdmin) {
            factory.setWalletsOnSplitter(splitter, manufacturerWallet, address(0));
            console2.log("  Splitter manufacturer wallet updated to:", manufacturerWallet);
        }

        // Grant MINTER_ROLE to the admin
        KonduxImplementation cloneContract = KonduxImplementation(payable(clone));
        bytes32 MINTER_ROLE = cloneContract.MINTER_ROLE();
        cloneContract.grantRole(MINTER_ROLE, cloneAdmin);
        console2.log("  MINTER_ROLE granted to admin:", cloneAdmin);
    }

    function _configureMarketplaceSecurity(address clone) internal {
        console2.log("  Configuring marketplace security...");

        // Check if transfer validator exists on Sepolia
        if (TRANSFER_VALIDATOR_MAINNET.code.length == 0) {
            console2.log("  WARNING: Transfer Validator not deployed on this network");
            console2.log("  Skipping marketplace security configuration");
            return;
        }

        console2.log("    Transfer Validator:", TRANSFER_VALIDATOR_MAINNET);

        // Try to set default security policy
        (bool success,) = clone.call(
            abi.encodeWithSignature("setToDefaultSecurityPolicy()")
        );

        if (success) {
            console2.log("    Default security policy set");
        } else {
            console2.log("    WARNING: Could not set security policy");
        }
    }

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
        // For Sepolia, we may not have an Authority contract deployed
        // Check if AUTHORITY env var is set, otherwise skip BatchMinter
        address authority = vm.envOr("AUTHORITY_ADDRESS", address(0));

        if (authority == address(0)) {
            console2.log("  WARNING: No AUTHORITY_ADDRESS set, skipping BatchMinter deployment");
            console2.log("  Set AUTHORITY_ADDRESS env var or DEPLOY_BATCH_MINTER=false");
            return address(0);
        }

        // Deploy BatchMinter pointing to the clone
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

        // Configure BatchMinter roles - grant BATCH_MINTER_ROLE to admin
        KonduxBatchMinter minter = KonduxBatchMinter(batchMinter);
        minter.grantRole(minter.BATCH_MINTER_ROLE(), admin);
        console2.log("  BATCH_MINTER_ROLE granted to admin");

        // Grant BATCH_MINTER_ROLE to signer if specified
        if (vm.envExists("BATCH_MINTER_SIGNER")) {
            address signer = vm.envAddress("BATCH_MINTER_SIGNER");
            minter.grantRole(minter.BATCH_MINTER_ROLE(), signer);
            console2.log("  BATCH_MINTER_ROLE granted to signer:", signer);
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

        // Check pause state
        console2.log("BatchMinter paused:", minter.paused());

        console2.log("");
    }

    function _printSummary(DeployResult memory result, bool isDryRun) internal pure {
        console2.log("========================================");
        console2.log("= DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("");

        if (isDryRun) {
            console2.log("STATUS: DRY RUN COMPLETE (no actual transactions)");
            console2.log("");
        }

        console2.log("Implementation:", result.implementation);
        console2.log("Factory:", result.factory);
        console2.log("Beacon:", result.beacon);

        if (result.clone != address(0)) {
            console2.log("");
            console2.log("=== Test Clone ===");
            console2.log("Clone:", result.clone);
            console2.log("Splitter (Royalty Receiver):", result.splitter);
            if (result.batchMinter != address(0)) {
                console2.log("BatchMinter:", result.batchMinter);
            }
        }

        console2.log("");
        console2.log("========================================");
        console2.log("= CONFIGURATION");
        console2.log("========================================");
        console2.log("Network: Sepolia (chainId 11155111)");
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
            console2.log("2. If everything looks correct, run with DRY_RUN=false --broadcast");
            console2.log("3. After deployment, verify contracts on Sepolia Etherscan");
        } else {
            console2.log("1. Verify contracts on Sepolia Etherscan:");
            console2.log("   https://sepolia.etherscan.io/");
            console2.log("2. Test minting via BatchMinter or direct safeMint");
            console2.log("3. Test royalty distribution via splitter");
        }

        console2.log("");
    }

    function _selectPrivateKey() internal view returns (uint256) {
        // For Sepolia (testnet), prefer DEPLOYER_PK over PROD_DEPLOYER_PK
        if (vm.envExists("DEPLOYER_PK")) {
            return vm.envUint("DEPLOYER_PK");
        }
        return vm.envUint("PROD_DEPLOYER_PK");
    }
}
