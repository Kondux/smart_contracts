// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {Authority} from "contracts/Authority.sol";

/**
 * @title DeployAuthorityScript
 * @notice Deploys the Authority governance contract
 * @dev Authority manages roles: governor, guardian, policy, vault
 *
 * Usage:
 *   forge script scripts/solidity/deploy/DeployAuthority.s.sol:DeployAuthorityScript \
 *     --rpc-url $RPC_URL --broadcast -vvv
 *
 * Environment variables:
 *   - DEPLOYER_PK: Private key for testnet deployments
 *   - PROD_DEPLOYER_PK: Private key for mainnet deployments
 *   - GOVERNOR (optional): Governor address (defaults to deployer)
 *   - GUARDIAN (optional): Guardian address (defaults to deployer)
 *   - POLICY (optional): Policy address (defaults to deployer)
 *   - VAULT (optional): Vault address (defaults to deployer)
 */
contract DeployAuthorityScript is Script {
    struct DeployConfig {
        string label;
        address governor;
        address guardian;
        address policy;
        address vault;
    }

    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== Authority Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", deployer.balance);

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        DeployConfig memory cfg = _loadConfig(deployer);

        vm.startBroadcast(deployerKey);

        Authority authority = new Authority(
            cfg.governor,
            cfg.guardian,
            cfg.policy,
            cfg.vault
        );

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network:", cfg.label);
        console2.log("Authority:", address(authority));
        console2.log("Governor:", cfg.governor);
        console2.log("Guardian:", cfg.guardian);
        console2.log("Policy:", cfg.policy);
        console2.log("Vault:", cfg.vault);
    }

    function _loadConfig(address deployer) internal view returns (DeployConfig memory cfg) {
        cfg.label = _networkLabel();

        // Use environment variables if set, otherwise default to deployer
        cfg.governor = vm.envOr("GOVERNOR", deployer);
        cfg.guardian = vm.envOr("GUARDIAN", deployer);
        cfg.policy = vm.envOr("POLICY", deployer);
        cfg.vault = vm.envOr("VAULT", deployer);

        // For mainnet, require explicit addresses
        if (block.chainid == 1) {
            require(cfg.governor != deployer || vm.envExists("GOVERNOR"), "Mainnet: GOVERNOR env required");
            require(cfg.guardian != deployer || vm.envExists("GUARDIAN"), "Mainnet: GUARDIAN env required");
            require(cfg.policy != deployer || vm.envExists("POLICY"), "Mainnet: POLICY env required");
            require(cfg.vault != deployer || vm.envExists("VAULT"), "Mainnet: VAULT env required");
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
        require(key != 0, "DeployAuthority: private key env var missing");
        return key;
    }
}
