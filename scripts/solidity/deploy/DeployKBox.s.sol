// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KBox} from "contracts/tests/KBox.sol";
import {Authority} from "contracts/Authority.sol";

/**
 * @title DeployKBoxScript
 * @notice Deploys the KBox NFT contract
 * @dev ERC721 with royalties and Authority-based access control
 *
 * Usage:
 *   forge script scripts/solidity/deploy/DeployKBox.s.sol:DeployKBoxScript \
 *     --rpc-url $RPC_URL --broadcast -vvv
 *
 * Environment variables:
 *   - DEPLOYER_PK: Private key for testnet deployments
 *   - PROD_DEPLOYER_PK: Private key for mainnet deployments
 *   - AUTHORITY: Authority contract address
 *   - NFT_NAME (optional): NFT collection name (default: "KBox")
 *   - NFT_SYMBOL (optional): NFT collection symbol (default: "KBOX")
 */
contract DeployKBoxScript is Script {
    struct DeployConfig {
        string label;
        string name;
        string symbol;
        address authority;
        bool deployAuthority;
    }

    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== KBox Deployment ===");
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

        KBox kBox = new KBox(cfg.name, cfg.symbol, authorityAddr);
        console2.log("KBox deployed:", address(kBox));

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network:", cfg.label);
        console2.log("KBox:", address(kBox));
        console2.log("Name:", cfg.name);
        console2.log("Symbol:", cfg.symbol);
        console2.log("Authority:", authorityAddr);
    }

    function _loadConfig(address deployer) internal view returns (DeployConfig memory cfg) {
        cfg.label = _networkLabel();
        cfg.name = vm.envOr("NFT_NAME", string("KBox"));
        cfg.symbol = vm.envOr("NFT_SYMBOL", string("KBOX"));

        if (block.chainid == 1) {
            // Mainnet
            cfg.authority = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
            cfg.deployAuthority = false;
        } else if (block.chainid == 11155111) {
            // Sepolia
            cfg.authority = vm.envOr("AUTHORITY", address(0xfF0b8218353F088173779B0079263F672Aa3B548));
            cfg.deployAuthority = false;
        } else {
            // Local
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
        require(key != 0, "DeployKBox: private key env var missing");
        return key;
    }
}
