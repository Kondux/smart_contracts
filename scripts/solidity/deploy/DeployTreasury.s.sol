// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {Treasury} from "contracts/Treasury.sol";
import {Authority} from "contracts/Authority.sol";

/**
 * @title DeployTreasuryScript
 * @notice Deploys the Treasury contract
 * @dev Treasury manages token deposits/withdrawals and integrates with Authority
 *
 * Usage:
 *   forge script scripts/solidity/deploy/DeployTreasury.s.sol:DeployTreasuryScript \
 *     --rpc-url $RPC_URL --broadcast -vvv
 *
 * Environment variables:
 *   - DEPLOYER_PK: Private key for testnet deployments
 *   - PROD_DEPLOYER_PK: Private key for mainnet deployments
 *   - AUTHORITY: Authority contract address (required for mainnet/sepolia)
 */
contract DeployTreasuryScript is Script {
    struct DeployConfig {
        string label;
        address authority;
        bool deployAuthority;
    }

    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== Treasury Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", deployer.balance);

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        DeployConfig memory cfg = _loadConfig(deployer);

        vm.startBroadcast(deployerKey);

        address authorityAddr = cfg.authority;

        // Deploy Authority if needed (local only)
        if (cfg.deployAuthority) {
            Authority authority = new Authority(deployer, deployer, deployer, deployer);
            authorityAddr = address(authority);
            console2.log("Authority deployed:", authorityAddr);
        }

        Treasury treasury = new Treasury(authorityAddr);
        console2.log("Treasury deployed:", address(treasury));

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network:", cfg.label);
        console2.log("Treasury:", address(treasury));
        console2.log("Authority:", authorityAddr);
    }

    function _loadConfig(address deployer) internal view returns (DeployConfig memory cfg) {
        cfg.label = _networkLabel();

        if (block.chainid == 1) {
            // Mainnet - use existing Authority
            cfg.authority = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
            cfg.deployAuthority = false;
        } else if (block.chainid == 11155111) {
            // Sepolia
            cfg.authority = vm.envOr("AUTHORITY", address(0xfF0b8218353F088173779B0079263F672Aa3B548));
            cfg.deployAuthority = false;
        } else {
            // Local - deploy fresh Authority or use provided
            if (vm.envExists("AUTHORITY")) {
                cfg.authority = vm.envAddress("AUTHORITY");
                cfg.deployAuthority = false;
            } else {
                cfg.deployAuthority = true;
            }
        }
    }

    function _networkLabel() internal view returns (string memory) {
        if (block.chainid == 1) return "Ethereum Mainnet";
        if (block.chainid == 11155111) return "Ethereum Sepolia";
        if (block.chainid == 31337) return "Local/Hardhat";
        return string.concat("Chain ", vm.toString(block.chainid));
    }

    function _selectPrivateKey() internal view returns (uint256) {
        string memory envName = (block.chainid == 1) ? "PROD_DEPLOYER_PK" : "DEPLOYER_PK";
        uint256 key = vm.envUint(envName);
        require(key != 0, "DeployTreasury: private key env var missing");
        return key;
    }
}
