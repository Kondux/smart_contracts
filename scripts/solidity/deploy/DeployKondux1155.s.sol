// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {Kondux1155} from "contracts/Kondux_1155_NFT.sol";

/**
 * @title DeployKondux1155Script
 * @notice Deploys the Kondux1155 ERC1155 NFT contract
 * @dev ERC1155 with DNA, roles, and pausable functionality
 *
 * Usage:
 *   forge script scripts/solidity/deploy/DeployKondux1155.s.sol:DeployKondux1155Script \
 *     --rpc-url $RPC_URL --broadcast -vvv
 *
 * Environment variables:
 *   - DEPLOYER_PK: Private key for testnet deployments
 *   - PROD_DEPLOYER_PK: Private key for mainnet deployments
 *   - BASE_URI (optional): Base URI for token metadata
 */
contract DeployKondux1155Script is Script {
    function run() external {
        uint256 deployerKey = _selectPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("=== Kondux1155 Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", deployer.balance);

        if (block.chainid == 31337) {
            vm.deal(deployer, 1_000 ether);
        }

        string memory baseURI = vm.envOr("BASE_URI", string(""));

        vm.startBroadcast(deployerKey);

        Kondux1155 kondux1155 = new Kondux1155();
        console2.log("Kondux1155 deployed:", address(kondux1155));

        // Set base URI if provided
        if (bytes(baseURI).length > 0) {
            kondux1155.setBaseURI(baseURI);
            console2.log("Base URI set:", baseURI);
        }

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Network:", _networkLabel());
        console2.log("Kondux1155:", address(kondux1155));
        console2.log("Admin:", deployer);
        if (bytes(baseURI).length > 0) {
            console2.log("Base URI:", baseURI);
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
        require(key != 0, "DeployKondux1155: private key env var missing");
        return key;
    }
}
