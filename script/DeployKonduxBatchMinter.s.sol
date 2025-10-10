// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {KonduxImplementation} from "../contracts/KonduxImplementation.sol";
import {KonduxBatchMinter} from "../contracts/KonduxBatchMinter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IUniswapV2Router02 {
    function factory() external view returns (address);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address);
    function createPair(address tokenA, address tokenB) external returns (address);
}

contract DeployKonduxBatchMinterScript is Script {
    using stdJson for string;

    struct DeployConfig {
        string label;
        string collectionName;
        string collectionSymbol;
        uint256 maxSupply;
        string baseURI;
        bool setBaseURI;
        bool setPartnerWallet;
        address partnerWallet;
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
        address[] konduxRoleRecipients;
        address[] konduxDnaRoleRecipients;
        address[] batchMinterRoleRecipients;
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
        console2.log("=== Kondux BatchMinter Deployment ===");
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
            pair,
            cfg.weth,
            cfg.kndx,
            cfg.foundersPass,
            cfg.treasury,
            cfg.maxSupply
        );
        ERC1967Proxy konduxProxy = new ERC1967Proxy(address(implementationLogic), initData);
        KonduxImplementation kondux = KonduxImplementation(payable(address(konduxProxy)));

        console2.log(string.concat("KonduxImplementation logic: ", vm.toString(address(implementationLogic))));
        console2.log(string.concat("KonduxImplementation proxy: ", vm.toString(address(kondux))));

        KonduxBatchMinter batchMinter = new KonduxBatchMinter(address(kondux), cfg.authority);
        console2.log(string.concat("KonduxBatchMinter deployed: ", vm.toString(address(batchMinter))));

        _applyKonduxSetup(kondux, batchMinter, cfg, pair, deployer);

        vm.stopBroadcast();

        _appendAddressBook(cfg, address(kondux), address(implementationLogic), address(batchMinter), pair, deployer);
    _attemptVerification(cfg, address(kondux), address(implementationLogic), address(batchMinter));

        console2.log("\nDeployment summary");
        console2.log("KonduxImplementation (proxy)", address(kondux));
        console2.log("KonduxImplementation logic", address(implementationLogic));
        console2.log("KonduxBatchMinter", address(batchMinter));
        console2.log("Authority", cfg.authority);
        console2.log("Treasury", cfg.treasury);
        console2.log("Founder pass", cfg.foundersPass);
        console2.log("KNDX token", cfg.kndx);
        console2.log("Payment token", cfg.paymentToken);
        console2.log("Uniswap pair", pair);
        if (cfg.partnerWallet != address(0)) {
            console2.log("Partner wallet", cfg.partnerWallet);
        }
        if (cfg.legacyKondux != address(0)) {
            console2.log("Legacy kNFT", cfg.legacyKondux);
        }
        if (cfg.helix != address(0)) {
            console2.log("Helix", cfg.helix);
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
            cfg.setPartnerWallet = true;
            cfg.partnerWallet = 0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E;
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

            cfg.konduxRoleRecipients = new address[](1);
            cfg.konduxRoleRecipients[0] = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;

            cfg.konduxDnaRoleRecipients = new address[](1);
            cfg.konduxDnaRoleRecipients[0] = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;

            cfg.batchMinterRoleRecipients = new address[](1);
            cfg.batchMinterRoleRecipients[0] = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
        } else if (block.chainid == 11155111) {
            cfg.label = "Ethereum Sepolia";
            cfg.collectionName = "Kondux kNFT (Sepolia)";
            cfg.collectionSymbol = "kNFTs";
            cfg.maxSupply = 0;
            cfg.baseURI = "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/";
            cfg.setBaseURI = true;
            cfg.setPartnerWallet = true;
            cfg.partnerWallet = 0xD5a6Af8F9C20CaF7872611d6773152aA50180f83;
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

            cfg.konduxRoleRecipients = new address[](1);
            cfg.konduxRoleRecipients[0] = cfg.admin;

            cfg.konduxDnaRoleRecipients = new address[](1);
            cfg.konduxDnaRoleRecipients[0] = cfg.admin;

            cfg.batchMinterRoleRecipients = new address[](1);
            cfg.batchMinterRoleRecipients[0] = cfg.admin;
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

    function _grantRoleIfNeeded(KonduxImplementation target, bytes32 role, address account, string memory label)
        internal
    {
        if (account == address(0)) return;
        if (target.hasRole(role, account)) {
            console2.log(string.concat(label, " already has role: ", vm.toString(account)));
            return;
        }
        target.grantRole(role, account);
        console2.log(string.concat(label, " granted role to ", vm.toString(account)));
    }

    function _grantRoleIfNeeded(KonduxBatchMinter target, bytes32 role, address account, string memory label)
        internal
    {
        if (account == address(0)) return;
        if (target.hasRole(role, account)) {
            console2.log(string.concat(label, " already has role: ", vm.toString(account)));
            return;
        }
        target.grantRole(role, account);
        console2.log(string.concat(label, " granted role to ", vm.toString(account)));
    }

    function _applyKonduxSetup(
        KonduxImplementation kondux,
        KonduxBatchMinter batchMinter,
        DeployConfig memory cfg,
        address pair,
        address deployer
    ) internal {
        bytes32 minterRole = kondux.MINTER_ROLE();
        bytes32 dnaRole = kondux.DNA_MODIFIER_ROLE();

        _grantRoleIfNeeded(kondux, minterRole, address(batchMinter), "KonduxImplementation");
        _grantRoleIfNeeded(kondux, dnaRole, address(batchMinter), "KonduxImplementation");

        for (uint256 i; i < cfg.konduxRoleRecipients.length; ++i) {
            _grantRoleIfNeeded(kondux, minterRole, cfg.konduxRoleRecipients[i], "KonduxImplementation");
        }
        for (uint256 i; i < cfg.konduxDnaRoleRecipients.length; ++i) {
            _grantRoleIfNeeded(kondux, dnaRole, cfg.konduxDnaRoleRecipients[i], "KonduxImplementation");
        }

        bytes32 batchMinterRole = batchMinter.BATCH_MINTER_ROLE();
        for (uint256 i; i < cfg.batchMinterRoleRecipients.length; ++i) {
            _grantRoleIfNeeded(batchMinter, batchMinterRole, cfg.batchMinterRoleRecipients[i], "KonduxBatchMinter");
        }

        _ensureKonduxCoreAddresses(kondux, cfg, pair);
        _applyKonduxPostSetup(kondux, cfg);

        _configureAdmins(kondux, deployer, cfg);
        _configureAdmins(batchMinter, deployer, cfg);
    }

    function _ensureKonduxCoreAddresses(KonduxImplementation kondux, DeployConfig memory cfg, address pair) internal {
        address currentPair = address(kondux.uniswapV2Pair());
        address currentWeth = kondux.WETH();
        address currentKndx = kondux.KNDX();
        address currentFounders = address(kondux.foundersPass());
        address currentTreasury = kondux.konduxTreasury();

        bool needsUpdate =
            currentPair != pair ||
            currentWeth != cfg.weth ||
            currentKndx != cfg.kndx ||
            currentFounders != cfg.foundersPass ||
            currentTreasury != cfg.treasury;

        if (needsUpdate) {
            kondux.setAddresses(pair, cfg.weth, cfg.kndx, cfg.foundersPass, cfg.treasury);
            console2.log("KonduxImplementation core addresses synchronised");
            console2.log(string.concat("  Uniswap pair -> ", vm.toString(pair)));
            console2.log(string.concat("  WETH -> ", vm.toString(cfg.weth)));
            console2.log(string.concat("  KNDX -> ", vm.toString(cfg.kndx)));
            console2.log(string.concat("  Founders pass -> ", vm.toString(cfg.foundersPass)));
            console2.log(string.concat("  Treasury -> ", vm.toString(cfg.treasury)));
        } else {
            console2.log("KonduxImplementation core addresses already configured");
        }
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

        if (cfg.setPartnerWallet && cfg.partnerWallet != address(0)) {
            address currentPartner = kondux.partnerWallet();
            if (currentPartner != cfg.partnerWallet) {
                kondux.setPartnerWallet(cfg.partnerWallet);
                console2.log(
                    string.concat("KonduxImplementation partner wallet set to ", vm.toString(cfg.partnerWallet))
                );
            } else {
                console2.log("KonduxImplementation partner wallet unchanged");
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

    function _configureAdmins(KonduxBatchMinter target, address deployer, DeployConfig memory cfg) internal {
        if (cfg.admin == address(0)) return;
        if (cfg.admin == deployer) return;

        bytes32 adminRole = target.DEFAULT_ADMIN_ROLE();
        target.grantRole(adminRole, cfg.admin);
        console2.log(string.concat("KonduxBatchMinter admin granted to ", vm.toString(cfg.admin)));
        if (cfg.revokeDeployerAdmin) {
            target.revokeRole(adminRole, deployer);
            console2.log("KonduxBatchMinter admin revoked from deployer");
        }
    }

    function setupExistingKondux(address konduxProxyAddr, address batchMinterAddr) external {
        require(konduxProxyAddr != address(0), "kondux proxy zero");
        require(batchMinterAddr != address(0), "batch minter zero");

        DeployConfig memory cfg = _loadConfig();
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        _ensureAlchemyProvider();
        string memory rpcHint = _alchemyProviderHint();
        if (bytes(rpcHint).length > 0) {
            console2.log(rpcHint);
        }

        console2.log("=== Kondux BatchMinter Setup (Existing) ===");
        console2.log(string.concat("Network label: ", cfg.label));
        console2.log(string.concat("Chain ID: ", vm.toString(block.chainid)));
        console2.log(string.concat("Deployer: ", vm.toString(deployer)));
        console2.log(string.concat("Deployer balance: ", vm.toString(deployer.balance)));
        console2.log(string.concat("KonduxImplementation target: ", vm.toString(konduxProxyAddr)));
        console2.log(string.concat("KonduxBatchMinter target: ", vm.toString(batchMinterAddr)));

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        vm.startBroadcast(deployerKey);

        address pair = _resolveUniswapPair(cfg);
        console2.log(string.concat("Using Uniswap pair: ", vm.toString(pair)));

        KonduxImplementation kondux = KonduxImplementation(payable(konduxProxyAddr));
        KonduxBatchMinter batchMinter = KonduxBatchMinter(batchMinterAddr);

        _applyKonduxSetup(kondux, batchMinter, cfg, pair, deployer);

        vm.stopBroadcast();

        console2.log("Existing deployment setup complete");
    }

    function _appendAddressBook(
        DeployConfig memory cfg,
        address konduxProxy,
        address konduxLogic,
        address batchMinter,
        address pair,
        address deployer
    ) internal {
        string memory bookPath =
            string.concat(vm.projectRoot(), "/docs/deployments/kondux-batchminter/address-book.json");

        string memory json;
        try vm.readFile(bookPath) returns (string memory contents) {
            json = contents;
        } catch {
            json = "";
        }

        if (bytes(json).length == 0) {
            json =
                "{\"schema\":\"kondux-batchminter-address-book\",\"networks\":{\"mainnet\":[],\"hardhat\":[],\"sepolia\":[]}}";
        }

        string memory version = string.concat(vm.toString(block.timestamp), "-", vm.toString(block.number));

        string memory entry = "{";
        entry = _appendStringField(entry, "version", version);
        entry = _appendRawField(entry, "chainId", vm.toString(block.chainid));
        entry = _appendStringField(entry, "konduxImplementationProxy", vm.toString(konduxProxy));
        entry = _appendStringField(entry, "konduxImplementationLogic", vm.toString(konduxLogic));
        entry = _appendStringField(entry, "konduxBatchMinter", vm.toString(batchMinter));
        entry = _appendStringField(entry, "konduxName", cfg.collectionName);
        entry = _appendStringField(entry, "konduxSymbol", cfg.collectionSymbol);
        entry = _appendStringField(entry, "authority", vm.toString(cfg.authority));
        if (cfg.admin != address(0)) {
            entry = _appendStringField(entry, "admin", vm.toString(cfg.admin));
        }
        entry = _appendStringField(entry, "treasury", vm.toString(cfg.treasury));
        entry = _appendStringField(entry, "foundersPass", vm.toString(cfg.foundersPass));
        entry = _appendStringField(entry, "paymentToken", vm.toString(cfg.paymentToken));
        entry = _appendStringField(entry, "kndxToken", vm.toString(cfg.kndx));
        entry = _appendStringField(entry, "weth", vm.toString(cfg.weth));
        entry = _appendStringField(entry, "uniswapPair", vm.toString(pair));
        entry = _appendStringField(entry, "uniswapRouter", vm.toString(cfg.router));
        if (cfg.partnerWallet != address(0)) {
            entry = _appendStringField(entry, "partnerWallet", vm.toString(cfg.partnerWallet));
        }
        if (cfg.legacyKondux != address(0)) {
            entry = _appendStringField(entry, "legacyKondux", vm.toString(cfg.legacyKondux));
        }
        if (cfg.helix != address(0)) {
            entry = _appendStringField(entry, "helix", vm.toString(cfg.helix));
        }
        string memory notes = string.concat("Deployer:", vm.toString(deployer));
        if (cfg.legacyKondux != address(0)) {
            notes = string.concat(notes, "|Legacy kNFT:", vm.toString(cfg.legacyKondux));
        }
        if (cfg.helix != address(0)) {
            notes = string.concat(notes, "|Helix:", vm.toString(cfg.helix));
        }
        entry = _appendStringField(entry, "notes", notes);
        entry = string.concat(entry, "}");

        string memory networkKey = _networkKey();
        string memory pathKey = string.concat("networks.", networkKey, "[]");
        json = json.serialize(pathKey, entry);

        vm.writeFile(bookPath, json);
        console2.log("Address book updated", bookPath);
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

    function _appendStringField(string memory json, string memory key, string memory value)
        internal
        pure
        returns (string memory)
    {
        return _appendFragment(json, string.concat("\"", key, "\":\"", value, "\""));
    }

    function _appendRawField(string memory json, string memory key, string memory value)
        internal
        pure
        returns (string memory)
    {
        return _appendFragment(json, string.concat("\"", key, "\":", value));
    }

    function _appendFragment(string memory json, string memory fragment) private pure returns (string memory) {
        return bytes(json).length == 1 ? string.concat(json, fragment) : string.concat(json, ",", fragment);
    }

    function _networkKey() internal view returns (string memory) {
        if (block.chainid == 1) return "mainnet";
        if (block.chainid == 31337) return "hardhat";
        if (block.chainid == 11155111) return "sepolia";
        revert("Unsupported chain id");
    }

    function _attemptVerification(
        DeployConfig memory cfg,
        address konduxProxy,
        address konduxLogic,
        address batchMinter
    ) internal {
        if (block.chainid != 1 && block.chainid != 11155111) {
            return;
        }
        uint256 verifyFlag = vm.envOr("VERIFY", uint256(0));
        if (verifyFlag == 0) {
            console2.log("Verification skipped (set VERIFY=1 to enable)");
            _printManualVerify(konduxProxy, konduxLogic, batchMinter, cfg);
            return;
        }

        string memory apiKey = vm.envOr("ETHERSCAN_API_KEY", string(""));
        if (bytes(apiKey).length == 0) {
            console2.log("ETHERSCAN_API_KEY missing, skipping verification");
            _printManualVerify(konduxProxy, konduxLogic, batchMinter, cfg);
            return;
        }

    bytes memory constructorArgs = abi.encode(konduxProxy, cfg.authority);
    string memory argHex = vm.toString(constructorArgs);

    console2.log("Manual verification commands (sanitised API key):");
    _emitVerifyCommand(konduxLogic, "contracts/KonduxImplementation.sol:KonduxImplementation", "");
    _emitVerifyCommand(batchMinter, "contracts/KonduxBatchMinter.sol:KonduxBatchMinter", argHex);
    _emitProxyVerifyCommand(konduxProxy, konduxLogic, "$ETHERSCAN_API_KEY");

    _runForgeVerify(konduxLogic, "contracts/KonduxImplementation.sol:KonduxImplementation", apiKey, "");
    _runForgeVerify(batchMinter, "contracts/KonduxBatchMinter.sol:KonduxBatchMinter", apiKey, argHex);
    _runForgeProxyVerify(konduxProxy, konduxLogic, apiKey);
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

    function _runForgeProxyVerify(address proxy, address implementation, string memory apiKey) internal {
        string[] memory cmd = _buildProxyVerifyCommandArgs(proxy, implementation, apiKey);

        VmSafe.FfiResult memory res = vm.tryFfi(cmd);
        bool ok = res.exitCode == 0;
        bytes memory out = res.stdout.length > 0 ? res.stdout : res.stderr;
        if (ok) {
            console2.log("Proxy verification submitted", proxy);
        } else {
            console2.log("Proxy verification failed", proxy);
            console2.log(string(out));
        }
    }

    function _emitVerifyCommand(address target, string memory contractPath, string memory constructorArgs)
        internal
        view
    {
        console2.log(_formatVerifyCommand(target, contractPath, constructorArgs, "$ETHERSCAN_API_KEY"));
    }

    function _emitProxyVerifyCommand(address proxy, address implementation, string memory apiKeyLabel) internal view {
        console2.log(_formatProxyVerifyCommand(proxy, implementation, apiKeyLabel));
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

    function _buildProxyVerifyCommandArgs(address proxy, address implementation, string memory apiKey)
        internal
        view
        returns (string[] memory cmd)
    {
        cmd = new string[](15);
        uint256 i;
        cmd[i++] = "forge";
        cmd[i++] = "verify-proxy";
        cmd[i++] = "--chain-id";
        cmd[i++] = vm.toString(block.chainid);
        cmd[i++] = "--etherscan-api-key";
        cmd[i++] = apiKey;
        cmd[i++] = "--proxy-type";
        cmd[i++] = "oz-upgrades";
        cmd[i++] = "--watch";
        cmd[i++] = "--retries";
        cmd[i++] = "12";
        cmd[i++] = "--delay";
        cmd[i++] = "10";
        cmd[i++] = vm.toString(proxy);
        cmd[i++] = vm.toString(implementation);
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

    function _formatProxyVerifyCommand(address proxy, address implementation, string memory apiKeyLabel)
        internal
        view
        returns (string memory)
    {
        return string.concat(
            "forge verify-proxy --chain-id ",
            vm.toString(block.chainid),
            " --etherscan-api-key ",
            apiKeyLabel,
            " --proxy-type oz-upgrades --watch --retries 12 --delay 10 ",
            vm.toString(proxy),
            " ",
            vm.toString(implementation)
        );
    }

    function _printManualVerify(
        address konduxProxy,
        address konduxLogic,
        address batchMinter,
        DeployConfig memory cfg
    ) internal view {
        string memory net = block.chainid == 1 ? "mainnet" : "sepolia";
        console2.log("Manual verification commands:");
        _emitVerifyCommand(konduxLogic, "contracts/KonduxImplementation.sol:KonduxImplementation", "");
        string memory manualArgs = vm.toString(abi.encode(konduxProxy, cfg.authority));
        _emitVerifyCommand(batchMinter, "contracts/KonduxBatchMinter.sol:KonduxBatchMinter", manualArgs);
        _emitProxyVerifyCommand(konduxProxy, konduxLogic, "$ETHERSCAN_API_KEY");
        console2.log(string.concat("(network: ", net, ")"));
    }
}
