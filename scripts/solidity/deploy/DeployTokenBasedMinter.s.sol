// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxTokenBasedMinter} from "contracts/KonduxTokenBasedMinter.sol";

/**
 * @title DeployTokenBasedMinterScript
 * @notice Deploys the KonduxTokenBasedMinter contract
 * @dev Minter that accepts ERC20 token payments with Uniswap price oracle
 *
 * Usage:
 *   forge script scripts/solidity/deploy/DeployTokenBasedMinter.s.sol:DeployTokenBasedMinterScript \
 *     --rpc-url $RPC_URL --broadcast -vvv
 *
 * Environment variables:
 *   - DEPLOYER_PK: Private key for testnet deployments
 *   - PROD_DEPLOYER_PK: Private key for mainnet deployments
 *   - KNFT: Kondux NFT contract address (required)
 *   - FOUNDERS_PASS: Founders Pass NFT address (required)
 *   - TREASURY: Treasury contract address (required)
 *   - PAYMENT_TOKEN: ERC20 payment token address (required)
 *   - UNISWAP_PAIR: Uniswap V2 pair address (required)
 *   - WETH: WETH contract address (required)
 */
contract DeployTokenBasedMinterScript is Script {
    struct DeployConfig {
        string label;
        address kNFT;
        address foundersPass;
        address treasury;
        address paymentToken;
        address uniswapPair;
        address weth;
    }

    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== KonduxTokenBasedMinter Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", deployer.balance);

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        DeployConfig memory cfg = _loadConfig();

        vm.startBroadcast(deployerKey);

        KonduxTokenBasedMinter minter = new KonduxTokenBasedMinter(
            cfg.kNFT,
            cfg.foundersPass,
            cfg.treasury,
            cfg.paymentToken,
            cfg.uniswapPair,
            cfg.weth
        );
        console2.log("KonduxTokenBasedMinter deployed:", address(minter));

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network:", cfg.label);
        console2.log("KonduxTokenBasedMinter:", address(minter));
        console2.log("kNFT:", cfg.kNFT);
        console2.log("Founders Pass:", cfg.foundersPass);
        console2.log("Treasury:", cfg.treasury);
        console2.log("Payment Token:", cfg.paymentToken);
        console2.log("Uniswap Pair:", cfg.uniswapPair);
        console2.log("WETH:", cfg.weth);
        console2.log("");
        console2.log("NOTE: Grant MINTER_ROLE on kNFT to this minter contract");
    }

    function _loadConfig() internal view returns (DeployConfig memory cfg) {
        cfg.label = _networkLabel();

        if (block.chainid == 1) {
            // Mainnet addresses
            cfg.kNFT = 0x5aD180dF8619CE4f888190C3a926111a723632ce;
            cfg.foundersPass = 0xD3f011f1768B38CcC0faA7B00E59B0E29920194b;
            cfg.treasury = 0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E;
            cfg.paymentToken = 0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1; // KNDX
            cfg.uniswapPair = 0x79dd15aD871b0fE18040a52F951D757Ef88cfe72;
            cfg.weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        } else if (block.chainid == 11155111) {
            // Sepolia - require env vars or use defaults
            cfg.kNFT = vm.envOr("KNFT", address(0));
            cfg.foundersPass = vm.envOr("FOUNDERS_PASS", address(0x434fD7FEEc752c4BfA4a59d0272c503ffD313499));
            cfg.treasury = vm.envOr("TREASURY", address(0xD5a6Af8F9C20CaF7872611d6773152aA50180f83));
            cfg.paymentToken = vm.envOr("PAYMENT_TOKEN", address(0x2fa9e338CFe579Ff4575BeD2e1Ea407e811F35bc));
            cfg.uniswapPair = vm.envOr("UNISWAP_PAIR", address(0));
            cfg.weth = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;

            require(cfg.kNFT != address(0), "Sepolia: KNFT env required");
            require(cfg.uniswapPair != address(0), "Sepolia: UNISWAP_PAIR env required");
        } else {
            // Local - require all env vars
            cfg.kNFT = vm.envAddress("KNFT");
            cfg.foundersPass = vm.envAddress("FOUNDERS_PASS");
            cfg.treasury = vm.envAddress("TREASURY");
            cfg.paymentToken = vm.envAddress("PAYMENT_TOKEN");
            cfg.uniswapPair = vm.envAddress("UNISWAP_PAIR");
            cfg.weth = vm.envAddress("WETH");
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
        require(key != 0, "DeployTokenBasedMinter: private key env var missing");
        return key;
    }
}
