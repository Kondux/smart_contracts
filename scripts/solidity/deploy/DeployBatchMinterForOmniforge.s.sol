// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../../../contracts/KonduxBatchMinter.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract DeployBatchMinterForOmniforge is Script {
    // Kondux Omniforge (CRTR) collection
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;
    // Authority contract
    address constant AUTHORITY = 0x6A005c11217863c4e300Ce009c5Ddc7e1672150A;
    // Admin
    address constant ADMIN = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;

    // Roles
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant DNA_MODIFIER_ROLE = keccak256("DNA_MODIFIER_ROLE");
    bytes32 constant BATCH_MINTER_ROLE = keccak256("BATCH_MINTER_ROLE");

    function run() external {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        vm.startBroadcast(deployerKey);

        // 1. Deploy BatchMinter
        KonduxBatchMinter batchMinter = new KonduxBatchMinter(
            COLLECTION,
            AUTHORITY
        );
        console.log("BatchMinter deployed at:", address(batchMinter));

        // 2. Grant MINTER_ROLE to BatchMinter on Collection
        IAccessControl(COLLECTION).grantRole(MINTER_ROLE, address(batchMinter));
        console.log("Granted MINTER_ROLE to BatchMinter on Collection");

        // 3. Grant DNA_MODIFIER_ROLE to BatchMinter on Collection
        IAccessControl(COLLECTION).grantRole(DNA_MODIFIER_ROLE, address(batchMinter));
        console.log("Granted DNA_MODIFIER_ROLE to BatchMinter on Collection");

        // 4. Grant BATCH_MINTER_ROLE to Admin on BatchMinter
        batchMinter.grantRole(BATCH_MINTER_ROLE, ADMIN);
        console.log("Granted BATCH_MINTER_ROLE to Admin on BatchMinter");

        vm.stopBroadcast();

        // Smoke tests
        console.log("\n=== Smoke Tests ===");
        console.log("BatchMinter.kondux():", address(batchMinter.kondux()));
        console.log("Has MINTER_ROLE:", IAccessControl(COLLECTION).hasRole(MINTER_ROLE, address(batchMinter)));
        console.log("Has DNA_MODIFIER_ROLE:", IAccessControl(COLLECTION).hasRole(DNA_MODIFIER_ROLE, address(batchMinter)));
        console.log("Admin has BATCH_MINTER_ROLE:", batchMinter.hasRole(BATCH_MINTER_ROLE, ADMIN));
    }
}
