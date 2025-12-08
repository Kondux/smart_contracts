// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {KonduxImplementation} from "../contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "../contracts/KonduxBeaconFactory.sol";

/// @notice Deploys the Kondux beacon factory and (optionally) a fresh
///         KonduxImplementation logic contract.  The factory owns the
///         beacon, so it can upgrade the implementation later.
contract DeployKonduxBeaconFactoryScript is Script {
    struct DeployConfig {
        string label; // Human readable network label
        address existingImplementation; // Reuse an already deployed logic contract (0x0 => deploy new)
        bool publicDeployment; // Whether anyone can deploy clones
        address[] cloneDeployers; // Addresses to grant CLONE_DEPLOYER_ROLE when gated
    }

    function run() external {
        DeployConfig memory cfg = _loadConfig();
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== Kondux Beacon Factory Deployment ===");
        console2.log(string.concat("Network label: ", cfg.label));
        console2.log(string.concat("Chain ID: ", vm.toString(block.chainid)));
        console2.log(string.concat("Deployer: ", vm.toString(deployer)));
        console2.log(string.concat("Deployer balance: ", vm.toString(deployer.balance)));

        vm.startBroadcast(deployerKey);

        address implementation = cfg.existingImplementation;
        bool deployedImplementation = false;
        if (implementation == address(0)) {
            implementation = address(new KonduxImplementation());
            deployedImplementation = true;
            console2.log("Deployed KonduxImplementation logic:", implementation);
        } else {
            console2.log("Using provided KonduxImplementation logic:", implementation);
        }

        KonduxBeaconFactory factory = new KonduxBeaconFactory(implementation);
        console2.log("KonduxBeaconFactory deployed:", address(factory));

        if (!cfg.publicDeployment) {
            factory.setPublicDeployment(false);
            console2.log("Public deployment disabled");
        }

        for (uint256 i = 0; i < cfg.cloneDeployers.length; ++i) {
            factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), cfg.cloneDeployers[i]);
            console2.log("Granted CLONE_DEPLOYER_ROLE:", cfg.cloneDeployers[i]);
        }

        if (!cfg.publicDeployment && cfg.cloneDeployers.length == 0) {
            factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), deployer);
            console2.log("Granted CLONE_DEPLOYER_ROLE to deployer:", deployer);
        }

        vm.stopBroadcast();

        _attemptVerification(implementation, address(factory), deployedImplementation);
        _printSummary(implementation, address(factory), cfg);
    }

    /* --------------------------------------------------------------------- */
    /* Config helpers                                                        */
    /* --------------------------------------------------------------------- */
    function _loadConfig() internal view returns (DeployConfig memory cfg) {
        // Defaults per network; override implementation via env when needed.
        if (block.chainid == 1) {
            cfg.label = "Ethereum Mainnet";
            cfg.publicDeployment = false;
        } else if (block.chainid == 11155111) {
            cfg.label = "Ethereum Sepolia";
            cfg.publicDeployment = true;
        } else if (block.chainid == 31337) {
            cfg.label = "Local / Anvil";
            cfg.publicDeployment = true;
        } else {
            cfg.label = string.concat("Chain ", vm.toString(block.chainid));
            cfg.publicDeployment = true;
        }

        // Optional env overrides
        if (vm.envExists("KONDUX_IMPL")) {
            cfg.existingImplementation = vm.envAddress("KONDUX_IMPL");
        }
        if (vm.envExists("PUBLIC_DEPLOYMENT")) {
            cfg.publicDeployment = vm.envBool("PUBLIC_DEPLOYMENT");
        }

        // Optional allowlist for gated deployments
        if (vm.envExists("CLONE_DEPLOYER")) {
            address single = vm.envAddress("CLONE_DEPLOYER");
            cfg.cloneDeployers = new address[](1);
            cfg.cloneDeployers[0] = single;
        }
    }

    function _selectPrivateKey() internal view returns (uint256) {
        if (block.chainid == 1 || block.chainid == 31337) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        return vm.envUint("DEPLOYER_PK");
    }

    /* --------------------------------------------------------------------- */
    /* Verification helpers (Etherscan style)                                */
    /* --------------------------------------------------------------------- */
    function _attemptVerification(address implementation, address factory, bool verifyImplementation) internal {
        if (block.chainid != 1 && block.chainid != 11155111) {
            return; // Only mainnet / sepolia support automatic verification here
        }

        uint256 verifyFlag = vm.envOr("VERIFY", uint256(0));
        if (verifyFlag == 0) {
            console2.log("Verification skipped (set VERIFY=1 to enable)");
            _printManualVerify(implementation, factory);
            return;
        }

        string memory apiKey = vm.envOr("ETHERSCAN_API_KEY", string(""));
        if (bytes(apiKey).length == 0) {
            console2.log("ETHERSCAN_API_KEY missing, skipping verification");
            _printManualVerify(implementation, factory);
            return;
        }

        if (verifyImplementation) {
            _runForgeVerify(implementation, "contracts/KonduxImplementation.sol:KonduxImplementation", apiKey, "");
        }

        string memory ctorArgs = vm.toString(abi.encode(implementation));
        _runForgeVerify(factory, "contracts/KonduxBeaconFactory.sol:KonduxBeaconFactory", apiKey, ctorArgs);
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

    function _printManualVerify(address implementation, address factory) internal view {
        console2.log("Manual verification commands:");
        console2.log(
            _formatVerifyCommand(
                implementation, "contracts/KonduxImplementation.sol:KonduxImplementation", "", "$ETHERSCAN_API_KEY"
            )
        );
        string memory ctorArgs = vm.toString(abi.encode(implementation));
        console2.log(
            _formatVerifyCommand(
                factory, "contracts/KonduxBeaconFactory.sol:KonduxBeaconFactory", ctorArgs, "$ETHERSCAN_API_KEY"
            )
        );
    }

    function _formatVerifyCommand(
        address target,
        string memory contractPath,
        string memory constructorArgs,
        string memory apiKeyLabel
    ) internal view returns (string memory) {
        string memory cmd = string.concat(
            "forge verify-contract --chain-id ", vm.toString(block.chainid), " --num-of-optimizations 800"
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

    /* --------------------------------------------------------------------- */
    /* Output helpers                                                        */
    /* --------------------------------------------------------------------- */
    function _printSummary(address implementation, address factory, DeployConfig memory cfg) internal view {
        console2.log("\nDeployment summary");
        console2.log("KonduxImplementation logic", implementation);
        console2.log("KonduxBeaconFactory", factory);
        console2.log("Public deployment", cfg.publicDeployment);
        if (cfg.cloneDeployers.length > 0) {
            console2.log("Clone deployers:");
            for (uint256 i = 0; i < cfg.cloneDeployers.length; ++i) {
                console2.log("  ", cfg.cloneDeployers[i]);
            }
        }
    }
}
