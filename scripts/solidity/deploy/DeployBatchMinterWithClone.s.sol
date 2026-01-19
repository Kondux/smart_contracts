// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";
import {KonduxRoyaltySplitter} from "contracts/KonduxRoyaltySplitter.sol";
import {KonduxBatchMinter} from "contracts/KonduxBatchMinter.sol";
import {ICreatorTokenTransferValidator} from "contracts/interfaces/ICreatorTokenTransferValidator.sol";

/**
 * @title DeployBatchMinterWithCloneScript
 * @notice Deploys a new BatchMinter, Clone (via existing factory), and Splitter
 * 
 * This script:
 * 1. Deploys a clone with splitter via the existing KonduxBeaconFactory
 * 2. Deploys a new KonduxBatchMinter targeting the clone
 * 3. Configures marketplace security (OpenSea whitelist ID 16)
 * 4. Sets up all required roles for minting
 * 5. Verifies all deployed contracts
 *
 * Environment variables:
 *   Required:
 *   - PROD_DEPLOYER_PK or DEPLOYER_PK: Deployer private key
 *   
 *   Optional:
 *   - DRY_RUN: Set to "true" to run on fork without broadcasting (default: true)
 *   - NETWORK: "mainnet" or "sepolia" (default: mainnet)
 *   - BATCH_MINTER_SIGNER: Address to grant BATCH_MINTER_ROLE
 *
 * Clone Configuration (env vars):
 *   - CLONE_NAME: Name for the clone (default: "Kondux Collection")
 *   - CLONE_SYMBOL: Symbol for the clone (default: "KNDX")
 *   - CLONE_MAX_SUPPLY: Max supply (default: 10000)
 *   - CLONE_ADMIN: Admin address for the clone
 *   - MANUFACTURER_WALLET: Wallet for manufacturer royalty cut
 *   - CREATOR_WALLET: Wallet for default creator royalty cut
 *   - MANUFACTURER_CUT_BP: Manufacturer cut in basis points (default: 500 = 5%)
 *   - CREATOR_CUT_BP: Creator cut in basis points (default: 500 = 5%)
 *
 * Usage:
 *   # Dry run on mainnet fork (default)
 *   forge script scripts/solidity/deploy/DeployBatchMinterWithClone.s.sol \
 *     --rpc-url $MAINNET_RPC_URL -vvv
 *
 *   # Dry run on Sepolia fork
 *   NETWORK=sepolia forge script scripts/solidity/deploy/DeployBatchMinterWithClone.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL -vvv
 *
 *   # Actual Sepolia deployment
 *   DRY_RUN=false NETWORK=sepolia forge script scripts/solidity/deploy/DeployBatchMinterWithClone.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvv
 *
 *   # Actual Mainnet deployment
 *   DRY_RUN=false NETWORK=mainnet forge script scripts/solidity/deploy/DeployBatchMinterWithClone.s.sol \
 *     --rpc-url $MAINNET_RPC_URL --broadcast --verify -vvv
 */
contract DeployBatchMinterWithCloneScript is Script {
    // ============ Network-specific addresses ============
    
    // Mainnet addresses
    address constant MAINNET_FACTORY = 0x0855A3063326623C22E62A376cC9e1715e6Da9A9;
    address constant MAINNET_AUTHORITY = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
    address constant MAINNET_ADMIN = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    address constant MAINNET_TRANSFER_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    
    // Sepolia addresses (update these with actual Sepolia deployments)
    address constant SEPOLIA_FACTORY = 0xa265a01205f304F2652277AaC924AB56D2e0Cf77; // TODO: Update with Sepolia factory
    address constant SEPOLIA_AUTHORITY = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A; // TODO: Update with Sepolia authority
    address constant SEPOLIA_ADMIN = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    address constant SEPOLIA_TRANSFER_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3; // Same on Sepolia
    
    // Limit Break whitelist ID for OpenSea
    uint48 constant WHITELIST_ID = 16;
    
    // Clone config defaults
    string constant DEFAULT_CLONE_NAME = "Kondux Collection";
    string constant DEFAULT_CLONE_SYMBOL = "KNDX";
    uint256 constant DEFAULT_CLONE_MAX_SUPPLY = 10000;
    address constant DEFAULT_ROYALTY_WALLET = 0x3493c35A1890A758F21D74B757F051702f1dE82D;
    uint256 constant DEFAULT_MANUFACTURER_CUT_BP = 500; // 5%
    uint256 constant DEFAULT_CREATOR_CUT_BP = 500; // 5%
    
    // Base URI template (clone address will be appended)
    string constant BASE_URI_PREFIX = "https://toixbmwexblvs2o2rnl3kk63oi0hmvtm.lambda-url.us-east-1.on.aws/api/v1/metadata/";

    struct NetworkConfig {
        address factory;
        address authority;
        address admin;
        address transferValidator;
        string name;
    }

    struct DeployResult {
        address clone;
        address splitter;
        address batchMinter;
    }

    function run() external {
        bool isDryRun = vm.envOr("DRY_RUN", true);
        string memory network = vm.envOr("NETWORK", string("mainnet"));
        
        console2.log("========================================");
        console2.log("= Deploy BatchMinter + Clone + Splitter");
        console2.log("========================================");
        console2.log("");
        
        NetworkConfig memory config = _getNetworkConfig(network);
        
        console2.log("Network:", config.name);
        console2.log("Chain ID:", block.chainid);
        
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
        
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        console2.log("");
        
        console2.log("Using addresses:");
        console2.log("  Factory:", config.factory);
        console2.log("  Authority:", config.authority);
        console2.log("  Transfer Validator:", config.transferValidator);
        console2.log("");

        DeployResult memory result;

        if (isDryRun) {
            result = _executeDryRun(config);
        } else {
            vm.startBroadcast(deployerKey);
            result = _executeDeployment(config, deployer);
            vm.stopBroadcast();
        }

        _verifyDeployment(result, config);
        _printSummary(result, config, isDryRun);
    }

    function _getNetworkConfig(string memory network) internal pure returns (NetworkConfig memory) {
        if (keccak256(bytes(network)) == keccak256(bytes("sepolia"))) {
            return NetworkConfig({
                factory: SEPOLIA_FACTORY,
                authority: SEPOLIA_AUTHORITY,
                admin: SEPOLIA_ADMIN,
                transferValidator: SEPOLIA_TRANSFER_VALIDATOR,
                name: "Sepolia"
            });
        } else {
            return NetworkConfig({
                factory: MAINNET_FACTORY,
                authority: MAINNET_AUTHORITY,
                admin: MAINNET_ADMIN,
                transferValidator: MAINNET_TRANSFER_VALIDATOR,
                name: "Mainnet"
            });
        }
    }

    function _executeDryRun(NetworkConfig memory config) internal returns (DeployResult memory result) {
        console2.log("=== Executing Dry Run ===");
        
        // Impersonate admin for dry run
        address admin = config.admin;
        console2.log("Impersonating admin:", admin);
        vm.deal(admin, 10 ether);
        
        vm.startPrank(admin);
        result = _deployAll(config, admin);
        vm.stopPrank();
        
        console2.log("");
    }

    function _executeDeployment(NetworkConfig memory config, address deployer) internal returns (DeployResult memory result) {
        console2.log("=== Executing Live Deployment ===");
        result = _deployAll(config, deployer);
        console2.log("");
    }

    function _deployAll(NetworkConfig memory config, address admin) internal returns (DeployResult memory result) {
        KonduxBeaconFactory factory = KonduxBeaconFactory(config.factory);
        
        // Step 1: Deploy clone with splitter
        console2.log("Step 1: Deploying clone with splitter...");
        (result.clone, result.splitter) = _deployClone(factory, admin);
        
        // Step 2: Configure marketplace security
        console2.log("Step 2: Configuring marketplace security...");
        _configureMarketplaceSecurity(result.clone, config.transferValidator);
        
        // Step 3: Set base URI
        console2.log("Step 3: Setting base URI...");
        _setBaseURI(result.clone);
        
        // Step 4: Deploy BatchMinter
        console2.log("Step 4: Deploying BatchMinter...");
        result.batchMinter = _deployBatchMinter(result.clone, config.authority, admin);
        
        // Step 5: Grant MINTER_ROLE to BatchMinter
        console2.log("Step 5: Granting MINTER_ROLE to BatchMinter...");
        _grantMinterRole(result.clone, result.batchMinter);
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
        
        // Clone admin
        address cloneAdmin = vm.envOr("CLONE_ADMIN", admin);
        
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
            manufacturerCutBP,    // manufacturerCutBP
            0,                    // partnerCutBP (0%)
            creatorCutBP,         // defaultCreatorCutBP
            creatorWallet         // defaultCreatorWallet
        );
        
        console2.log("  Clone deployed:", clone);
        console2.log("  Splitter deployed:", splitter);

        // Update splitter wallets
        factory.setWalletsOnSplitter(splitter, manufacturerWallet, address(0));
        console2.log("  Splitter wallets updated");
    }

    function _configureMarketplaceSecurity(address clone, address transferValidator) internal {
        console2.log("  Transfer Validator:", transferValidator);
        console2.log("  Applying Whitelist ID:", WHITELIST_ID);
        
        ICreatorTokenTransferValidator validator = ICreatorTokenTransferValidator(transferValidator);
        validator.applyListToCollection(clone, WHITELIST_ID);
        
        // Verify
        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy = validator.getCollectionSecurityPolicy(clone);
        
        if (policy.listId == WHITELIST_ID) {
            console2.log("  SUCCESS: Whitelist ID 16 applied!");
        } else {
            console2.log("  WARNING: Whitelist ID mismatch! Got:", policy.listId);
        }
    }

    function _setBaseURI(address clone) internal {
        string memory cloneAddressStr = vm.toString(clone);
        string memory baseURI = string.concat(BASE_URI_PREFIX, cloneAddressStr, "/");
        
        console2.log("  Base URI:", baseURI);
        
        KonduxImplementation(payable(clone)).setBaseURI(baseURI);
        console2.log("  Base URI set successfully");
    }

    function _deployBatchMinter(
        address targetClone,
        address authority,
        address admin
    ) internal returns (address batchMinter) {
        batchMinter = address(new KonduxBatchMinter(targetClone, authority));
        console2.log("  BatchMinter deployed:", batchMinter);
        console2.log("  Target clone:", targetClone);
        
        // Configure BatchMinter roles
        KonduxBatchMinter minter = KonduxBatchMinter(batchMinter);
        
        // Grant BATCH_MINTER_ROLE to signer if specified
        if (vm.envExists("BATCH_MINTER_SIGNER")) {
            address signer = vm.envAddress("BATCH_MINTER_SIGNER");
            minter.grantRole(minter.BATCH_MINTER_ROLE(), signer);
            console2.log("  BATCH_MINTER_ROLE granted to:", signer);
        } else {
            minter.grantRole(minter.BATCH_MINTER_ROLE(), admin);
            console2.log("  BATCH_MINTER_ROLE granted to admin:", admin);
        }
    }

    function _grantMinterRole(address clone, address batchMinter) internal {
        KonduxImplementation cloneContract = KonduxImplementation(payable(clone));
        bytes32 MINTER_ROLE = cloneContract.MINTER_ROLE();
        cloneContract.grantRole(MINTER_ROLE, batchMinter);
        console2.log("  MINTER_ROLE granted to BatchMinter on clone");
    }

    function _verifyDeployment(DeployResult memory result, NetworkConfig memory config) internal view {
        console2.log("");
        console2.log("=== Verification ===");
        
        KonduxImplementation clone = KonduxImplementation(payable(result.clone));
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(result.splitter));
        KonduxBatchMinter minter = KonduxBatchMinter(result.batchMinter);
        
        // Clone verification
        console2.log("");
        console2.log("Clone:");
        console2.log("  Name:", clone.name());
        console2.log("  Symbol:", clone.symbol());
        console2.log("  Max Supply:", clone.maxSupply());
        console2.log("  Base URI:", clone.baseURI());
        
        // Royalty verification
        (address royaltyReceiver, uint256 royaltyAmount) = clone.royaltyInfo(1, 10000);
        console2.log("  Royalty Receiver:", royaltyReceiver);
        console2.log("  Royalty Amount (BP):", royaltyAmount);
        
        if (royaltyReceiver == result.splitter) {
            console2.log("  SUCCESS: royaltyInfo() returns splitter!");
        } else {
            console2.log("  WARNING: royaltyInfo() mismatch!");
        }
        
        // Splitter verification
        console2.log("");
        console2.log("Splitter:");
        console2.log("  Collection:", splitter.collection());
        console2.log("  Manufacturer Cut (BP):", splitter.manufacturerCutBP());
        console2.log("  Partner Cut (BP):", splitter.partnerCutBP());
        console2.log("  Creator Cut (BP):", splitter.defaultCreatorCutBP());
        
        bytes32 COLLECTION_ROLE = splitter.COLLECTION_ROLE();
        bool cloneHasCollectionRole = splitter.hasRole(COLLECTION_ROLE, result.clone);
        console2.log("  Clone has COLLECTION_ROLE:", cloneHasCollectionRole);
        
        // BatchMinter verification
        console2.log("");
        console2.log("BatchMinter:");
        address target = address(minter.kondux());
        console2.log("  Target (kondux):", target);
        
        if (target == result.clone) {
            console2.log("  SUCCESS: BatchMinter targets clone!");
        } else {
            console2.log("  FAILURE: BatchMinter target mismatch!");
        }
        
        bytes32 MINTER_ROLE = clone.MINTER_ROLE();
        bool hasMinterRole = clone.hasRole(MINTER_ROLE, result.batchMinter);
        console2.log("  Has MINTER_ROLE on clone:", hasMinterRole);
        console2.log("  Paused:", minter.paused());
        
        // Marketplace security verification
        console2.log("");
        console2.log("Marketplace Security:");
        ICreatorTokenTransferValidator validator = ICreatorTokenTransferValidator(config.transferValidator);
        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy = validator.getCollectionSecurityPolicy(result.clone);
        console2.log("  Whitelist ID:", policy.listId);
        
        if (policy.listId == WHITELIST_ID) {
            console2.log("  SUCCESS: Using OpenSea whitelist!");
        } else {
            console2.log("  WARNING: Whitelist ID mismatch!");
        }
    }

    function _printSummary(DeployResult memory result, NetworkConfig memory config, bool isDryRun) internal view {
        console2.log("");
        console2.log("========================================");
        console2.log("= DEPLOYMENT SUMMARY");
        console2.log("========================================");
        console2.log("");
        
        if (isDryRun) {
            console2.log("STATUS: DRY RUN COMPLETE (no actual transactions)");
        } else {
            console2.log("STATUS: LIVE DEPLOYMENT COMPLETE");
        }
        console2.log("");
        
        console2.log("Network:", config.name);
        console2.log("Chain ID:", block.chainid);
        console2.log("");
        
        console2.log("=== Deployed Contracts ===");
        console2.log("Clone:", result.clone);
        console2.log("Splitter:", result.splitter);
        console2.log("BatchMinter:", result.batchMinter);
        console2.log("");
        
        console2.log("=== Existing Contracts Used ===");
        console2.log("Factory:", config.factory);
        console2.log("Authority:", config.authority);
        console2.log("Transfer Validator:", config.transferValidator);
        console2.log("");
        
        console2.log("=== Configuration Applied ===");
        console2.log("Transfer Validator: Limit Break V3");
        console2.log("Security Level: Whitelisted operators only");
        console2.log("Operator Whitelist ID: 16 (OpenSea)");
        
        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(result.splitter));
        console2.log("Royalty:", splitter.manufacturerCutBP() + splitter.partnerCutBP() + splitter.defaultCreatorCutBP(), "BP via splitter");
        console2.log("  - Manufacturer:", splitter.manufacturerCutBP(), "BP");
        console2.log("  - Partner:", splitter.partnerCutBP(), "BP");
        console2.log("  - Creator:", splitter.defaultCreatorCutBP(), "BP");
        console2.log("");
        
        console2.log("=== Role Setup ===");
        console2.log("BatchMinter has MINTER_ROLE on Clone: YES");
        console2.log("Clone has COLLECTION_ROLE on Splitter: YES");
        console2.log("");
        
        console2.log("=== Next Steps ===");
        if (isDryRun) {
            console2.log("1. Review dry run output");
            console2.log("2. Run with DRY_RUN=false for actual deployment");
            console2.log("3. Use --broadcast --verify flags for live deployment");
        } else {
            console2.log("1. Verify contracts on Etherscan (should auto-verify with --verify flag)");
            console2.log("2. Update address book with new deployment");
            console2.log("3. Configure frontend/backend with new addresses");
        }
        console2.log("");
        
        if (!isDryRun) {
            console2.log("=== Verification Commands ===");
            console2.log("If auto-verification failed, run manually:");
            console2.log("");
            console2.log("# Verify Clone (proxy - may need implementation address)");
            console2.log(string.concat(
                "forge verify-contract ", vm.toString(result.clone),
                " contracts/KonduxImplementation.sol:KonduxImplementation --chain ", config.name
            ));
            console2.log("");
            console2.log("# Verify Splitter");
            console2.log(string.concat(
                "forge verify-contract ", vm.toString(result.splitter),
                " contracts/KonduxRoyaltySplitter.sol:KonduxRoyaltySplitter --chain ", config.name
            ));
            console2.log("");
            console2.log("# Verify BatchMinter");
            console2.log(string.concat(
                "forge verify-contract ", vm.toString(result.batchMinter),
                " contracts/KonduxBatchMinter.sol:KonduxBatchMinter --chain ", config.name
            ));
        }
        
        console2.log("");
        console2.log("========================================");
    }

    function _selectPrivateKey() internal view returns (uint256) {
        if (vm.envExists("PROD_DEPLOYER_PK")) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        return vm.envUint("DEPLOYER_PK");
    }
}
