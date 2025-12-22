// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {KonduxImplementation} from "../contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "../contracts/KonduxBeaconFactory.sol";
import {KonduxRoyaltySplitter} from "../contracts/KonduxRoyaltySplitter.sol";

/**
 * @title DeployCollectionWithSplitter
 * @notice Deploys a new NFT collection with an integrated royalty splitter
 * @dev Supports local/Anvil, Sepolia testnet, and Ethereum mainnet
 *
 * Environment variables:
 *   Required:
 *     - DEPLOYER_PK or PROD_DEPLOYER_PK: Deployer private key
 *
 *   Optional:
 *     - FACTORY_ADDRESS: Existing factory address (deploys new if not set)
 *     - COLLECTION_NAME: NFT collection name (default: "Kondux Collection")
 *     - COLLECTION_SYMBOL: NFT symbol (default: "KNDX")
 *     - MAX_SUPPLY: Maximum token supply (default: 10000)
 *     - PARTNER_WALLET: Partner address for royalty splits (default: deployer)
 *     - MANUFACTURER_CUT_BP: Manufacturer cut in basis points (default: 400 = 4%)
 *     - PARTNER_CUT_BP: Partner cut in basis points (default: 300 = 3%)
 *     - CREATOR_CUT_BP: Default creator cut in basis points (default: 300 = 3%)
 *     - DEPLOY_SPLITTER: Whether to deploy splitter (default: true)
 *     - RUN_SMOKE_TEST: Run smoke tests after deployment (default: true)
 *     - VERIFY: Enable Etherscan verification (default: 0)
 *     - ETHERSCAN_API_KEY: API key for verification
 *
 * Usage:
 *   # Local (Anvil)
 *   forge script script/DeployCollectionWithSplitter.s.sol --rpc-url http://localhost:8545 --broadcast
 *
 *   # Sepolia
 *   forge script script/DeployCollectionWithSplitter.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
 *
 *   # Mainnet
 *   forge script script/DeployCollectionWithSplitter.s.sol --rpc-url $MAINNET_RPC_URL --broadcast
 */
contract DeployCollectionWithSplitterScript is Script {
    struct DeployConfig {
        string networkLabel;
        address factoryAddress;
        string collectionName;
        string collectionSymbol;
        uint256 maxSupply;
        address collectionAdmin;
        address partnerWallet;
        address defaultCreatorWallet;
        uint96 manufacturerCutBP;
        uint96 partnerCutBP;
        uint96 creatorCutBP;
        bool deploySplitter;
        bool runSmokeTest;
    }

    struct DeployResult {
        address factory;
        address implementation;
        address collection;
        address splitter;
        bool factoryDeployed;
        bool implementationDeployed;
    }

    function run() external returns (DeployResult memory result) {
        DeployConfig memory cfg = _loadConfig();
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        _printHeader(cfg, deployer);

        vm.startBroadcast(deployerKey);

        // Step 1: Get or deploy factory
        KonduxBeaconFactory factory;
        if (cfg.factoryAddress != address(0)) {
            factory = KonduxBeaconFactory(cfg.factoryAddress);
            console2.log("Using existing factory:", cfg.factoryAddress);
        } else {
            KonduxImplementation impl = new KonduxImplementation();
            result.implementation = address(impl);
            result.implementationDeployed = true;
            console2.log("Deployed KonduxImplementation:", address(impl));

            factory = new KonduxBeaconFactory(address(impl));
            result.factoryDeployed = true;
            console2.log("Deployed KonduxBeaconFactory:", address(factory));
        }
        result.factory = address(factory);

        // Step 2: Deploy collection with splitter
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            cfg.collectionName,
            cfg.collectionSymbol,
            cfg.maxSupply,
            cfg.collectionAdmin
        );

        if (cfg.deploySplitter) {
            (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
                initData,
                true,
                cfg.partnerWallet,
                cfg.manufacturerCutBP,
                cfg.partnerCutBP,
                cfg.creatorCutBP,
                cfg.defaultCreatorWallet
            );
            result.collection = collectionAddr;
            result.splitter = splitterAddr;
            console2.log("Deployed Collection:", collectionAddr);
            console2.log("Deployed Splitter:", splitterAddr);
        } else {
            address collectionAddr = factory.deployClone(initData);
            result.collection = collectionAddr;
            console2.log("Deployed Collection (no splitter):", collectionAddr);
        }

        vm.stopBroadcast();

        // Step 3: Run smoke tests
        if (cfg.runSmokeTest) {
            _runSmokeTests(result, cfg);
        }

        // Step 4: Attempt verification
        _attemptVerification(result, cfg);

        // Step 5: Print summary
        _printSummary(result, cfg);

        return result;
    }

    /*//////////////////////////////////////////////////////////////
                            CONFIG LOADING
    //////////////////////////////////////////////////////////////*/

    function _loadConfig() internal view returns (DeployConfig memory cfg) {
        // Network-specific defaults
        if (block.chainid == 1) {
            cfg.networkLabel = "Ethereum Mainnet";
        } else if (block.chainid == 11155111) {
            cfg.networkLabel = "Ethereum Sepolia";
        } else if (block.chainid == 31337) {
            cfg.networkLabel = "Local / Anvil";
        } else {
            cfg.networkLabel = string.concat("Chain ", vm.toString(block.chainid));
        }

        // Load from environment with defaults
        cfg.factoryAddress = vm.envOr("FACTORY_ADDRESS", address(0));
        cfg.collectionName = vm.envOr("COLLECTION_NAME", string("Kondux Collection"));
        cfg.collectionSymbol = vm.envOr("COLLECTION_SYMBOL", string("KNDX"));
        cfg.maxSupply = vm.envOr("MAX_SUPPLY", uint256(10000));

        // Admin defaults to deployer
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);
        cfg.collectionAdmin = vm.envOr("COLLECTION_ADMIN", deployer);
        cfg.partnerWallet = vm.envOr("PARTNER_WALLET", deployer);
        cfg.defaultCreatorWallet = vm.envOr("DEFAULT_CREATOR_WALLET", deployer);

        // Royalty cuts (basis points)
        cfg.manufacturerCutBP = uint96(vm.envOr("MANUFACTURER_CUT_BP", uint256(400)));
        cfg.partnerCutBP = uint96(vm.envOr("PARTNER_CUT_BP", uint256(300)));
        cfg.creatorCutBP = uint96(vm.envOr("CREATOR_CUT_BP", uint256(300)));

        // Flags
        cfg.deploySplitter = vm.envOr("DEPLOY_SPLITTER", true);
        cfg.runSmokeTest = vm.envOr("RUN_SMOKE_TEST", true);

        // Validate cuts don't exceed 10%
        require(
            cfg.manufacturerCutBP + cfg.partnerCutBP + cfg.creatorCutBP <= 1000,
            "Total cuts exceed 10%"
        );
    }

    function _selectPrivateKey() internal view returns (uint256) {
        if (block.chainid == 1) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        return vm.envUint("DEPLOYER_PK");
    }

    /*//////////////////////////////////////////////////////////////
                            SMOKE TESTS
    //////////////////////////////////////////////////////////////*/

    function _runSmokeTests(DeployResult memory result, DeployConfig memory cfg) internal view {
        console2.log("\n=== Running Smoke Tests ===");

        bool allPassed = true;

        // Test 1: Collection basic info
        KonduxImplementation collection = KonduxImplementation(payable(result.collection));

        if (keccak256(bytes(collection.name())) != keccak256(bytes(cfg.collectionName))) {
            console2.log("FAIL: Collection name mismatch");
            allPassed = false;
        } else {
            console2.log("PASS: Collection name correct");
        }

        if (keccak256(bytes(collection.symbol())) != keccak256(bytes(cfg.collectionSymbol))) {
            console2.log("FAIL: Collection symbol mismatch");
            allPassed = false;
        } else {
            console2.log("PASS: Collection symbol correct");
        }

        // Test 2: Splitter configuration (if deployed)
        if (result.splitter != address(0)) {
            KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(result.splitter));

            if (splitter.collection() != result.collection) {
                console2.log("FAIL: Splitter collection mismatch");
                allPassed = false;
            } else {
                console2.log("PASS: Splitter linked to collection");
            }

            if (splitter.manufacturerCutBP() != cfg.manufacturerCutBP) {
                console2.log("FAIL: Manufacturer cut mismatch");
                allPassed = false;
            } else {
                console2.log("PASS: Manufacturer cut correct");
            }

            if (splitter.partnerCutBP() != cfg.partnerCutBP) {
                console2.log("FAIL: Partner cut mismatch");
                allPassed = false;
            } else {
                console2.log("PASS: Partner cut correct");
            }

            if (splitter.defaultCreatorCutBP() != cfg.creatorCutBP) {
                console2.log("FAIL: Creator cut mismatch");
                allPassed = false;
            } else {
                console2.log("PASS: Creator cut correct");
            }

            if (!splitter.pushModeEnabled()) {
                console2.log("FAIL: Push mode not enabled");
                allPassed = false;
            } else {
                console2.log("PASS: Push mode enabled");
            }

            // Test 3: ERC2981 royalty info points to splitter
            (address receiver, uint256 royaltyAmount) = collection.royaltyInfo(0, 10000);
            uint256 expectedRoyalty = (10000 * (cfg.manufacturerCutBP + cfg.partnerCutBP + cfg.creatorCutBP)) / 10000;

            if (receiver != result.splitter) {
                console2.log("FAIL: ERC2981 receiver is not splitter");
                allPassed = false;
            } else {
                console2.log("PASS: ERC2981 points to splitter");
            }

            if (royaltyAmount != expectedRoyalty) {
                console2.log("FAIL: ERC2981 royalty amount incorrect");
                console2.log("  Expected:", expectedRoyalty);
                console2.log("  Actual:", royaltyAmount);
                allPassed = false;
            } else {
                console2.log("PASS: ERC2981 royalty amount correct");
            }

            // Test 4: Factory tracking
            KonduxBeaconFactory factory = KonduxBeaconFactory(result.factory);
            if (factory.collectionToSplitter(result.collection) != result.splitter) {
                console2.log("FAIL: Factory tracking incorrect");
                allPassed = false;
            } else {
                console2.log("PASS: Factory tracking correct");
            }
        }

        if (allPassed) {
            console2.log("\nAll smoke tests PASSED");
        } else {
            console2.log("\nSome smoke tests FAILED");
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function _attemptVerification(DeployResult memory result, DeployConfig memory cfg) internal {
        if (block.chainid != 1 && block.chainid != 11155111) {
            return;
        }

        uint256 verifyFlag = vm.envOr("VERIFY", uint256(0));
        if (verifyFlag == 0) {
            console2.log("\nVerification skipped (set VERIFY=1 to enable)");
            _printManualVerifyCommands(result);
            return;
        }

        string memory apiKey = vm.envOr("ETHERSCAN_API_KEY", string(""));
        if (bytes(apiKey).length == 0) {
            console2.log("\nETHERSCAN_API_KEY missing, skipping verification");
            _printManualVerifyCommands(result);
            return;
        }

        console2.log("\n=== Verifying Contracts ===");

        if (result.implementationDeployed) {
            _runForgeVerify(
                result.implementation,
                "contracts/KonduxImplementation.sol:KonduxImplementation",
                apiKey,
                ""
            );
        }

        if (result.factoryDeployed) {
            string memory factoryArgs = vm.toString(abi.encode(result.implementation));
            _runForgeVerify(
                result.factory,
                "contracts/KonduxBeaconFactory.sol:KonduxBeaconFactory",
                apiKey,
                factoryArgs
            );
        }

        if (result.splitter != address(0)) {
            // Get splitter constructor args
            KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(result.splitter));
            string memory splitterArgs = vm.toString(abi.encode(
                result.collection,
                splitter.manufacturerWallet(),
                splitter.partnerWallet(),
                cfg.manufacturerCutBP,
                cfg.partnerCutBP,
                cfg.creatorCutBP,
                result.factory // Factory is admin
            ));
            _runForgeVerify(
                result.splitter,
                "contracts/KonduxRoyaltySplitter.sol:KonduxRoyaltySplitter",
                apiKey,
                splitterArgs
            );
        }
    }

    function _runForgeVerify(
        address target,
        string memory contractPath,
        string memory apiKey,
        string memory constructorArgs
    ) internal {
        string[] memory cmd = _buildVerifyCommandArgs(target, contractPath, apiKey, constructorArgs);

        VmSafe.FfiResult memory res = vm.tryFfi(cmd);
        bool ok = res.exitCode == 0;
        if (ok) {
            console2.log("Verification submitted:", target);
        } else {
            console2.log("Verification failed:", target);
            console2.log(string(res.stderr));
        }
    }

    function _buildVerifyCommandArgs(
        address target,
        string memory contractPath,
        string memory apiKey,
        string memory constructorArgs
    ) internal view returns (string[] memory cmd) {
        bool hasConstructor = bytes(constructorArgs).length > 0;
        uint256 length = hasConstructor ? 17 : 15;
        cmd = new string[](length);
        uint256 i;
        cmd[i++] = "forge";
        cmd[i++] = "verify-contract";
        cmd[i++] = "--chain-id";
        cmd[i++] = vm.toString(block.chainid);
        cmd[i++] = "--num-of-optimizations";
        cmd[i++] = "800";
        if (hasConstructor) {
            cmd[i++] = "--constructor-args";
            cmd[i++] = constructorArgs;
        }
        cmd[i++] = "--etherscan-api-key";
        cmd[i++] = apiKey;
        cmd[i++] = "--watch";
        cmd[i++] = "--retries";
        cmd[i++] = "12";
        cmd[i++] = "--delay";
        cmd[i++] = "10";
        cmd[i++] = vm.toString(target);
        cmd[i++] = contractPath;
    }

    function _printManualVerifyCommands(DeployResult memory result) internal view {
        console2.log("\nManual verification commands:");

        if (result.implementationDeployed) {
            console2.log(_formatVerifyCommand(
                result.implementation,
                "contracts/KonduxImplementation.sol:KonduxImplementation",
                ""
            ));
        }

        if (result.factoryDeployed) {
            string memory factoryArgs = vm.toString(abi.encode(result.implementation));
            console2.log(_formatVerifyCommand(
                result.factory,
                "contracts/KonduxBeaconFactory.sol:KonduxBeaconFactory",
                factoryArgs
            ));
        }

        if (result.splitter != address(0)) {
            console2.log("# Splitter verification requires constructor args - see deployment output");
        }
    }

    function _formatVerifyCommand(
        address target,
        string memory contractPath,
        string memory constructorArgs
    ) internal view returns (string memory) {
        string memory cmd = string.concat(
            "forge verify-contract --chain-id ",
            vm.toString(block.chainid),
            " --num-of-optimizations 800"
        );
        if (bytes(constructorArgs).length > 0) {
            cmd = string.concat(cmd, " --constructor-args ", constructorArgs);
        }
        cmd = string.concat(
            cmd,
            " --etherscan-api-key $ETHERSCAN_API_KEY ",
            vm.toString(target),
            " ",
            contractPath
        );
        return cmd;
    }

    /*//////////////////////////////////////////////////////////////
                            OUTPUT
    //////////////////////////////////////////////////////////////*/

    function _printHeader(DeployConfig memory cfg, address deployer) internal view {
        console2.log("=== Collection + Splitter Deployment ===");
        console2.log("Network:", cfg.networkLabel);
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer Balance:", deployer.balance);
        console2.log("");
        console2.log("Configuration:");
        console2.log("  Collection Name:", cfg.collectionName);
        console2.log("  Symbol:", cfg.collectionSymbol);
        console2.log("  Max Supply:", cfg.maxSupply);
        console2.log("  Collection Admin:", cfg.collectionAdmin);
        console2.log("  Partner Wallet:", cfg.partnerWallet);
        console2.log("  Default Creator Wallet:", cfg.defaultCreatorWallet);
        console2.log("  Deploy Splitter:", cfg.deploySplitter);
        if (cfg.deploySplitter) {
            console2.log("  Manufacturer Cut:", cfg.manufacturerCutBP, "BP");
            console2.log("  Partner Cut:", cfg.partnerCutBP, "BP");
            console2.log("  Creator Cut:", cfg.creatorCutBP, "BP");
            console2.log("  Total Royalty:", cfg.manufacturerCutBP + cfg.partnerCutBP + cfg.creatorCutBP, "BP");
        }
        console2.log("");
    }

    function _printSummary(DeployResult memory result, DeployConfig memory cfg) internal view {
        console2.log("\n=== Deployment Summary ===");
        if (result.factoryDeployed) {
            console2.log("Factory (NEW):", result.factory);
        } else {
            console2.log("Factory (existing):", result.factory);
        }
        if (result.implementationDeployed) {
            console2.log("Implementation (NEW):", result.implementation);
        }
        console2.log("Collection:", result.collection);
        if (result.splitter != address(0)) {
            console2.log("Splitter:", result.splitter);
        }

        console2.log("\n--- Addresses to Save ---");
        console2.log(string.concat("FACTORY_ADDRESS=", vm.toString(result.factory)));
        console2.log(string.concat("COLLECTION_ADDRESS=", vm.toString(result.collection)));
        if (result.splitter != address(0)) {
            console2.log(string.concat("SPLITTER_ADDRESS=", vm.toString(result.splitter)));
        }
    }
}
