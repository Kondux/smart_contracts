// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {MinterBundle} from "contracts/Minter_Bundle.sol";

/**
 * @title DeployMinterBundleScript
 * @notice Deploys the MinterBundle contract
 * @dev ETH-based NFT bundle minter with whitelist and founders pass support
 *
 * Usage:
 *   forge script scripts/solidity/deploy/DeployMinterBundle.s.sol:DeployMinterBundleScript \
 *     --rpc-url $RPC_URL --broadcast -vvv
 *
 * Environment variables:
 *   - DEPLOYER_PK: Private key for testnet deployments
 *   - PROD_DEPLOYER_PK: Private key for mainnet deployments
 *   - KNFT: Kondux NFT contract address (required)
 *   - KBOX: KBox NFT contract address (required)
 *   - FOUNDERS_PASS: Founders Pass NFT address (required)
 *   - TREASURY: Treasury contract address (required)
 */
contract DeployMinterBundleScript is Script {
    struct DeployConfig {
        string label;
        address kNFT;
        address kBox;
        address foundersPass;
        address treasury;
    }

    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== MinterBundle Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", deployer.balance);

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        DeployConfig memory cfg = _loadConfig();

        vm.startBroadcast(deployerKey);

        MinterBundle minter = new MinterBundle(
            cfg.kNFT,
            cfg.kBox,
            cfg.foundersPass,
            cfg.treasury
        );
        console2.log("MinterBundle deployed:", address(minter));

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network:", cfg.label);
        console2.log("MinterBundle:", address(minter));
        console2.log("kNFT:", cfg.kNFT);
        console2.log("kBox:", cfg.kBox);
        console2.log("Founders Pass:", cfg.foundersPass);
        console2.log("Treasury:", cfg.treasury);
        console2.log("");
        console2.log("NOTE: Grant MINTER_ROLE on kNFT to this minter contract");
        console2.log("NOTE: Set treasury permission for this minter as RESERVEDEPOSITOR");
    }

    function _loadConfig() internal view returns (DeployConfig memory cfg) {
        cfg.label = _networkLabel();

        if (block.chainid == 1) {
            // Mainnet addresses
            cfg.kNFT = 0x5aD180dF8619CE4f888190C3a926111a723632ce;
            cfg.kBox = 0x7eD509A69F7FD93fD59A557369a9a5dCc1499685;
            cfg.foundersPass = 0xD3f011f1768B38CcC0faA7B00E59B0E29920194b;
            cfg.treasury = 0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E;
        } else if (block.chainid == 11155111) {
            // Sepolia
            cfg.kNFT = vm.envOr("KNFT", address(0));
            cfg.kBox = vm.envOr("KBOX", address(0));
            cfg.foundersPass = vm.envOr("FOUNDERS_PASS", address(0x434fD7FEEc752c4BfA4a59d0272c503ffD313499));
            cfg.treasury = vm.envOr("TREASURY", address(0xD5a6Af8F9C20CaF7872611d6773152aA50180f83));

            require(cfg.kNFT != address(0), "Sepolia: KNFT env required");
            require(cfg.kBox != address(0), "Sepolia: KBOX env required");
        } else {
            // Local - require all env vars
            cfg.kNFT = vm.envAddress("KNFT");
            cfg.kBox = vm.envAddress("KBOX");
            cfg.foundersPass = vm.envAddress("FOUNDERS_PASS");
            cfg.treasury = vm.envAddress("TREASURY");
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
        require(key != 0, "DeployMinterBundle: private key env var missing");
        return key;
    }
}
