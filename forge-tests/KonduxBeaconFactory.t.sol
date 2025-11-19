// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxBeaconFactory.sol";
import "../contracts/KonduxImplementation.sol";

contract KonduxBeaconFactoryTest is Test {
    KonduxBeaconFactory factory;
    KonduxImplementation impl;
    
    address deployer = address(0x1);
    address user = address(0x2);
    address otherUser = address(0x3);
    
    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);
        
        vm.startPrank(deployer);
        impl = new KonduxImplementation();
        factory = new KonduxBeaconFactory(address(impl));
        vm.stopPrank();
    }

    function test_DeployClone_Public() public {
        vm.startPrank(user);
        
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "Test", "TST", 
            1000,
            user // Initial Admin
        );
        
        address cloneAddress = factory.deployClone(initData);
        KonduxImplementation clone = KonduxImplementation(payable(cloneAddress));
        
        // Check ownership/roles
        bool userIsAdmin = clone.hasRole(clone.DEFAULT_ADMIN_ROLE(), user);
        bool factoryIsAdmin = clone.hasRole(clone.DEFAULT_ADMIN_ROLE(), address(factory));
        
        assertTrue(userIsAdmin, "User should be admin");
        assertFalse(factoryIsAdmin, "Factory should not be admin");
        
        vm.stopPrank();
    }

    function test_DeployClone_Restricted() public {
        vm.startPrank(deployer);
        factory.setPublicDeployment(false);
        vm.stopPrank();

        vm.startPrank(user);
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "Test", "TST", 
            1000,
            user
        );
        
        vm.expectRevert(); // Should revert because user doesn't have CLONE_DEPLOYER_ROLE
        factory.deployClone(initData);
        vm.stopPrank();

        // Grant role and try again
        vm.startPrank(deployer);
        factory.grantRole(factory.CLONE_DEPLOYER_ROLE(), user);
        vm.stopPrank();

        vm.startPrank(user);
        factory.deployClone(initData);
        vm.stopPrank();
    }
}
