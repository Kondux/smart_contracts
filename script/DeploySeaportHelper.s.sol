// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {SeaportHelper} from "../contracts/helpers/SeaportHelper.sol";

contract DeploySeaportHelperScript is Script {
    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== SeaportHelper Deployment ===");
        console2.log(string.concat("Chain ID: ", vm.toString(block.chainid)));
        console2.log(string.concat("Deployer: ", vm.toString(deployer)));
        console2.log(string.concat("Deployer balance: ", vm.toString(deployer.balance)));

        vm.startBroadcast(deployerKey);

        SeaportHelper helper = new SeaportHelper();

        console2.log(string.concat("SeaportHelper deployed at: ", vm.toString(address(helper))));

        vm.stopBroadcast();

        _attemptVerification(address(helper));
    }

    function _selectPrivateKey() internal view returns (uint256) {
        if (block.chainid == 1 || block.chainid == 31337) {
            return vm.envUint("PROD_DEPLOYER_PK");
        }
        return vm.envUint("DEPLOYER_PK");
    }

    function _attemptVerification(address target) internal {
        if (block.chainid != 1 && block.chainid != 11155111) {
            return;
        }
        uint256 verifyFlag = vm.envOr("VERIFY", uint256(0));
        if (verifyFlag == 0) {
            console2.log("Verification skipped (set VERIFY=1 to enable)");
            _printManualVerify(target);
            return;
        }

        string memory apiKey = vm.envOr("ETHERSCAN_API_KEY", string(""));
        if (bytes(apiKey).length == 0) {
            console2.log("ETHERSCAN_API_KEY missing, skipping verification");
            _printManualVerify(target);
            return;
        }

        console2.log("Verifying contract...");
        _runForgeVerify(target, "contracts/helpers/SeaportHelper.sol:SeaportHelper", apiKey, "");
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
        cmd[i++] = "800"; // Matching other scripts
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

    function _printManualVerify(address target) internal view {
        string memory cmd = string.concat(
            "forge verify-contract --chain-id ",
            vm.toString(block.chainid),
            " --num-of-optimizations 800 --etherscan-api-key $ETHERSCAN_API_KEY --watch ",
            vm.toString(target),
            " contracts/helpers/SeaportHelper.sol:SeaportHelper"
        );
        console2.log("Manual verification command:");
        console2.log(cmd);
    }
}
