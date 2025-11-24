// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {KonduxImplementation} from "../contracts/KonduxImplementation.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IUniswapV2Router02 {
    function factory() external view returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address);
    function createPair(address tokenA, address tokenB) external returns (address);
}

contract DeployKonduxImplementationScript is Script {
    using stdJson for string;

    struct DeployConfig {
        string label;
        string collectionName;
        string collectionSymbol;
        uint256 maxSupply;
        string baseURI;
        bool setBaseURI;
        bool setTransferValidator;
        address transferValidator;
        bool setValidatorAutoApprove;
        bool validatorAutoApprove;
        bool setFreeMinting;
        bool freeMintingEnabled;
        address legacyKondux;
        address helix;
        address authority;
        address admin;
        address treasury;
        address foundersPass;
        address paymentToken;
        address kndx;
        address weth;
        address router;
        address existingPair;
        bool createPairIfMissing;
        bool revokeDeployerAdmin;
    }

    function run() external {
        DeployConfig memory cfg = _loadConfig();
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        _ensureAlchemyProvider();
        string memory rpcHint = _alchemyProviderHint();
        if (bytes(rpcHint).length > 0) {
            console2.log(rpcHint);
        }
        console2.log("=== Kondux Implementation Deployment ===");
        console2.log(string.concat("Network label: ", cfg.label));
        console2.log(string.concat("Chain ID: ", vm.toString(block.chainid)));
        console2.log(string.concat("Deployer: ", vm.toString(deployer)));
        console2.log(string.concat("Deployer balance: ", vm.toString(deployer.balance)));

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        vm.startBroadcast(deployerKey);

        address pair = _resolveUniswapPair(cfg);
        console2.log(string.concat("Using Uniswap pair: ", vm.toString(pair)));

        KonduxImplementation implementationLogic = new KonduxImplementation();
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            cfg.collectionName,
            cfg.collectionSymbol,
            cfg.maxSupply,
            deployer
        );
        ERC1967Proxy konduxProxy = new ERC1967Proxy(address(implementationLogic), initData);
        KonduxImplementation kondux = KonduxImplementation(payable(address(konduxProxy)));

        console2.log(string.concat("KonduxImplementation logic: ", vm.toString(address(implementationLogic))));
        console2.log(string.concat("KonduxImplementation proxy: ", vm.toString(address(kondux))));

        _applyKonduxPostSetup(kondux, cfg);
        _configureAdmins(kondux, deployer, cfg);

        vm.stopBroadcast();

        _attemptVerification(cfg, address(kondux), address(implementationLogic));

        console2.log("\nDeployment summary");
        console2.log("KonduxImplementation (proxy)", address(kondux));
        console2.log("KonduxImplementation logic", address(implementationLogic));
        console2.log("Authority", cfg.authority);
        console2.log("Treasury", cfg.treasury);
        console2.log("Founder pass", cfg.foundersPass);
        console2.log("KNDX token", cfg.kndx);
        console2.log("Payment token", cfg.paymentToken);
        console2.log("Uniswap pair", pair);
        if (cfg.transferValidator != address(0)) {
            console2.log("Transfer validator", cfg.transferValidator);
        }
        if (cfg.setValidatorAutoApprove) {
            console2.log(
                "Validator auto-approve",
                cfg.validatorAutoApprove
            );
        }
    }

    function _loadConfig() internal view returns (DeployConfig memory cfg) {
        if (block.chainid == 1 || block.chainid == 31337) {
            cfg.label = block.chainid == 1 ? "Ethereum Mainnet" : "Hardhat (Mainnet Fork)";
            cfg.collectionName = "Kondux kNFT";
            cfg.collectionSymbol = "kNFT";
            cfg.maxSupply = 0;
            cfg.baseURI = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/";
            cfg.setBaseURI = true;
            cfg.setTransferValidator = false;
            cfg.transferValidator = address(0);
            cfg.setValidatorAutoApprove = true;
            cfg.validatorAutoApprove = true;
            cfg.setFreeMinting = true;
            cfg.freeMintingEnabled = false;
            cfg.legacyKondux = 0x5aD180dF8619CE4f888190C3a926111a723632ce;
            cfg.helix = address(0);
            cfg.authority = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
            cfg.admin = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
            cfg.treasury = 0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E;
            cfg.foundersPass = 0xD3f011f1768B38CcC0faA7B00E59B0E29920194b;
            cfg.paymentToken = 0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1;
            cfg.kndx = 0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1;
            cfg.weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            cfg.router = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
            cfg.existingPair = 0x79dd15aD871b0fE18040a52F951D757Ef88cfe72;
            cfg.createPairIfMissing = false;
            cfg.revokeDeployerAdmin = block.chainid == 1;
        } else if (block.chainid == 11155111) {
            cfg.label = "Ethereum Sepolia";
            cfg.collectionName = "Kondux kNFT (Sepolia)";
            cfg.collectionSymbol = "kNFTs";
            cfg.maxSupply = 0;
            cfg.baseURI = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/";
            cfg.setBaseURI = true;
            cfg.setTransferValidator = false;
            cfg.transferValidator = address(0);
            cfg.setValidatorAutoApprove = true;
            cfg.validatorAutoApprove = true;
            cfg.setFreeMinting = true;
            cfg.freeMintingEnabled = false;
            cfg.legacyKondux = address(0);
            cfg.helix = 0xb94F89750d9889656a6D081A0F06cBd3FA3Ad04B;
            cfg.authority = 0xfF0b8218353F088173779B0079263F672Aa3B548;
            cfg.admin = _testnetAdmin();
            cfg.treasury = 0xD5a6Af8F9C20CaF7872611d6773152aA50180f83;
            cfg.foundersPass = 0x434fD7FEEc752c4BfA4a59d0272c503ffD313499;
            cfg.paymentToken = 0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc;
            cfg.kndx = 0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc;
            cfg.weth = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
            cfg.router = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
            cfg.existingPair = address(0);
            cfg.createPairIfMissing = true;
            cfg.revokeDeployerAdmin = false;
        } else {
            revert("Unsupported chain id");
        }
    }

    function _testnetAdmin() internal view returns (address) {
        string memory fallbackUser = vm.envOr("USER_ADDRESS", string("0x9767a2B120614F526e923DAAF89843EC7C2292d7"));
        return vm.parseAddress(fallbackUser);
    }

    function _selectPrivateKey() internal view returns (uint256) {
        if (block.chainid == 1 || block.chainid == 31337) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        return vm.envUint("DEPLOYER_PK");
    }

    function _resolveUniswapPair(DeployConfig memory cfg) internal returns (address pair) {
        if (cfg.existingPair != address(0)) {
            return cfg.existingPair;
        }

        IUniswapV2Router02 router = IUniswapV2Router02(cfg.router);
        address factoryAddr = router.factory();
        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddr);

        pair = factory.getPair(cfg.weth, cfg.paymentToken);
        if (pair != address(0)) {
            return pair;
        }

        if (!cfg.createPairIfMissing) {
            revert("Uniswap pair missing and creation disabled");
        }

        pair = factory.createPair(cfg.weth, cfg.paymentToken);
    }

    function _applyKonduxPostSetup(KonduxImplementation kondux, DeployConfig memory cfg) internal {
        if (cfg.setBaseURI && bytes(cfg.baseURI).length > 0) {
            string memory current = kondux.baseURI();
            if (keccak256(bytes(current)) != keccak256(bytes(cfg.baseURI))) {
                kondux.setBaseURI(cfg.baseURI);
                console2.log(string.concat("KonduxImplementation baseURI set to ", cfg.baseURI));
            } else {
                console2.log("KonduxImplementation baseURI already set");
            }
        }

        if (cfg.setTransferValidator) {
            address desiredValidator = cfg.transferValidator;
            address currentValidator = kondux.getTransferValidator();
            if (currentValidator != desiredValidator) {
                kondux.setTransferValidator(desiredValidator);
                console2.log(
                    string.concat(
                        "KonduxImplementation transfer validator set to ",
                        vm.toString(desiredValidator)
                    )
                );
            } else {
                console2.log("KonduxImplementation transfer validator unchanged");
            }
        }

        if (cfg.setValidatorAutoApprove) {
            bool currentAuto = kondux.autoApproveTransfersFromValidator();
            if (currentAuto != cfg.validatorAutoApprove) {
                kondux.setAutomaticApprovalOfTransfersFromValidator(cfg.validatorAutoApprove);
                console2.log(
                    string.concat(
                        "KonduxImplementation validator auto-approval set to ",
                        cfg.validatorAutoApprove ? "true" : "false"
                    )
                );
            } else {
                console2.log("KonduxImplementation validator auto-approval unchanged");
            }
        }

        if (cfg.setFreeMinting) {
            bool currentFree = kondux.freeMinting();
            if (currentFree != cfg.freeMintingEnabled) {
                kondux.setFreeMinting(cfg.freeMintingEnabled);
                console2.log(
                    string.concat("KonduxImplementation freeMinting set to ", cfg.freeMintingEnabled ? "true" : "false")
                );
            } else {
                console2.log("KonduxImplementation freeMinting unchanged");
            }
        }
    }

    function _configureAdmins(KonduxImplementation target, address deployer, DeployConfig memory cfg) internal {
        if (cfg.admin == address(0)) return;
        if (cfg.admin == deployer) return;

        bytes32 adminRole = target.DEFAULT_ADMIN_ROLE();
        target.grantRole(adminRole, cfg.admin);
        console2.log(string.concat("KonduxImplementation admin granted to ", vm.toString(cfg.admin)));
        if (cfg.revokeDeployerAdmin) {
            target.revokeRole(adminRole, deployer);
            console2.log("KonduxImplementation admin revoked from deployer");
        }
    }

    function _ensureAlchemyProvider() internal view {
        if (block.chainid == 1) {
            if (!_hasNonEmptyEnv("ALCHEMY_MAINNET_API_KEY") && !_hasNonEmptyEnv("ALCHEMY_API_KEY")) {
                revert("Missing Alchemy API key (set ALCHEMY_MAINNET_API_KEY or ALCHEMY_API_KEY)");
            }
        } else if (block.chainid == 11155111) {
            if (!_hasNonEmptyEnv("ALCHEMY_SEPOLIA_API_KEY") && !_hasNonEmptyEnv("ALCHEMY_API_KEY")) {
                revert("Missing Alchemy API key (set ALCHEMY_SEPOLIA_API_KEY or ALCHEMY_API_KEY)");
            }
        }
    }

    function _alchemyProviderHint() internal view returns (string memory) {
        if (block.chainid == 1) {
            if (_hasNonEmptyEnv("ALCHEMY_MAINNET_API_KEY")) {
                return "Using Alchemy mainnet endpoint (ALCHEMY_MAINNET_API_KEY)";
            }
            if (_hasNonEmptyEnv("ALCHEMY_API_KEY")) {
                return "Using Alchemy mainnet endpoint (ALCHEMY_API_KEY)";
            }
        } else if (block.chainid == 11155111) {
            if (_hasNonEmptyEnv("ALCHEMY_SEPOLIA_API_KEY")) {
                return "Using Alchemy sepolia endpoint (ALCHEMY_SEPOLIA_API_KEY)";
            }
            if (_hasNonEmptyEnv("ALCHEMY_API_KEY")) {
                return "Using Alchemy sepolia endpoint (ALCHEMY_API_KEY)";
            }
        } else if (block.chainid == 31337) {
            if (_hasNonEmptyEnv("ALCHEMY_MAINNET_API_KEY")) {
                return "Using local fork backed by Alchemy mainnet endpoint";
            }
        }
        return "";
    }

    function _hasNonEmptyEnv(string memory name) private view returns (bool) {
        if (!vm.envExists(name)) {
            return false;
        }
        string memory value = vm.envOr(name, string(""));
        return bytes(value).length > 0;
    }

    function _attemptVerification(
        DeployConfig memory cfg,
        address konduxProxy,
        address konduxLogic
    ) internal {
        if (block.chainid != 1 && block.chainid != 11155111) {
            return;
        }
        uint256 verifyFlag = vm.envOr("VERIFY", uint256(0));
        if (verifyFlag == 0) {
            console2.log("Verification skipped (set VERIFY=1 to enable)");
            _printManualVerify(konduxProxy, konduxLogic, cfg);
            return;
        }

        string memory apiKey = vm.envOr("ETHERSCAN_API_KEY", string(""));
        if (bytes(apiKey).length == 0) {
            console2.log("ETHERSCAN_API_KEY missing, skipping verification");
            _printManualVerify(konduxProxy, konduxLogic, cfg);
            return;
        }

        console2.log("Manual verification commands (sanitised API key):");
        _emitVerifyCommand(konduxLogic, "contracts/KonduxImplementation.sol:KonduxImplementation", "");
        _printProxyVerificationReminder(konduxProxy, konduxLogic);

        _runForgeVerify(konduxLogic, "contracts/KonduxImplementation.sol:KonduxImplementation", apiKey, "");
        _printProxyVerificationReminder(konduxProxy, konduxLogic);
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
        bytes memory out = res.stdout.length > 0 ? res.stdout : res.stderr;
        if (ok) {
            console2.log("Verification submitted", target);
        } else {
            console2.log("Verification command failed", target);
            console2.log(string(out));
        }
    }

    function _emitVerifyCommand(address target, string memory contractPath, string memory constructorArgs)
        internal
        view
    {
        console2.log(_formatVerifyCommand(target, contractPath, constructorArgs, "$ETHERSCAN_API_KEY"));
    }

    function _printProxyVerificationReminder(address proxy, address implementation) internal view {
        console2.log("Proxy verification requires manual confirmation on Etherscan:");
        console2.log(string.concat("  * Proxy address   : ", vm.toString(proxy)));
        console2.log(string.concat("  * Implementation  : ", vm.toString(implementation)));
        console2.log("    Use Etherscan's proxy verification flow to link these once the logic contract is verified.");
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

    function _formatVerifyCommand(
        address target,
        string memory contractPath,
        string memory constructorArgs,
        string memory apiKeyLabel
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
            " --etherscan-api-key ",
            apiKeyLabel,
            " --watch --retries 12 --delay 10 ",
            vm.toString(target),
            " ",
            contractPath
        );
        return cmd;
    }

    function _printManualVerify(
        address konduxProxy,
        address konduxLogic,
        DeployConfig memory cfg
    ) internal view {
        string memory net = block.chainid == 1 ? "mainnet" : "sepolia";
        console2.log("Manual verification commands:");
        _emitVerifyCommand(konduxLogic, "contracts/KonduxImplementation.sol:KonduxImplementation", "");
        _printProxyVerificationReminder(konduxProxy, konduxLogic);
        console2.log(string.concat("(network: ", net, ")"));
    }
}
