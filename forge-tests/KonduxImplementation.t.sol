// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxBeaconFactory.sol";
import "../contracts/tests/MockKonduxERC20.sol";

contract KonduxImplementationTest is Test {
    KonduxImplementation public impl;
    KonduxBeaconFactory public factory;
    KonduxImplementation public kondux;

    address public deployer = address(0x100);
    address public admin = address(0x101);
    address public minter = address(0x102);
    address public dnaModifier = address(0x103);
    address public user1 = address(0x104);
    address public user2 = address(0x105);
    address public partner = address(0x106);

    // Limit Break Addresses (Mainnet)
    address public constant LB_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    function setUp() public {
        // Fork Mainnet
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);

        vm.startPrank(deployer);

        // Deploy Implementation
        impl = new KonduxImplementation();

        // Deploy Factory
        factory = new KonduxBeaconFactory(address(impl));

        // Deploy Clone
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "KonduxNFT",
            "kNFT",
            1000, // Max Supply
            deployer, // Initial Admin
            address(factory), // Factory for security config
            address(0) // No splitter
        );

        address cloneAddr = factory.deployClone(initData);
        kondux = KonduxImplementation(payable(cloneAddr));

        // Setup Roles
        kondux.grantRole(kondux.DEFAULT_ADMIN_ROLE(), admin);
        kondux.grantRole(kondux.MINTER_ROLE(), minter);
        kondux.grantRole(kondux.DNA_MODIFIER_ROLE(), dnaModifier);

        vm.stopPrank();
    }

    function test_Initialization() public view {
        assertEq(kondux.name(), "KonduxNFT");
        assertEq(kondux.symbol(), "kNFT");
        assertEq(kondux.maxSupply(), 1000);
        assertTrue(kondux.hasRole(kondux.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(kondux.hasRole(kondux.MINTER_ROLE(), minter));
        assertTrue(kondux.hasRole(kondux.DNA_MODIFIER_ROLE(), dnaModifier));
    }

    function test_Minting() public {
        vm.prank(minter);
        kondux.safeMint(user1, 12345);
        
        assertEq(kondux.ownerOf(0), user1);
        assertEq(kondux.getDna(0), 12345);
        assertEq(kondux.totalSupply(), 1);
    }

    function test_FreeMinting() public {
        vm.prank(user1);
        vm.expectRevert("kNFT: only minter");
        kondux.safeMint(user1, 111);

        vm.prank(admin);
        kondux.setFreeMinting(true);

        vm.prank(user1);
        kondux.safeMint(user1, 111);
        assertEq(kondux.ownerOf(0), user1);
    }

    function test_DNA() public {
        vm.prank(minter);
        kondux.safeMint(user1, 0);

        vm.prank(user1);
        vm.expectRevert("kNFT: only dna modifier");
        kondux.setDna(0, 999);

        vm.prank(dnaModifier);
        kondux.setDna(0, 999);
        assertEq(kondux.getDna(0), 999);
    }

    function test_WriteGen() public {
        vm.prank(minter);
        kondux.safeMint(user1, 0);

        // Write 0xbeef to bytes 30-32 (last 2 bytes)
        vm.prank(dnaModifier);
        kondux.writeGen(0, 0xbeef, 30, 32);

        uint256 dna = kondux.getDna(0);
        assertEq(dna & 0xffff, 0xbeef);
    }

    function test_RoyaltySplits() public {
        vm.startPrank(admin);
        kondux.setPartnerWallet(partner);
        // Set splits: 40% manufacturer, 30% partner, 30% creator = 100% total
        kondux.setRoyaltySplits(4000, 3000, 3000); 
        vm.stopPrank();

        (address receiver, uint256 amount) = kondux.royaltyInfo(0, 10000);
        assertEq(receiver, partner);
        assertEq(amount, 10000); 
    }
    
    function test_TransferValidator() public {
        // Check default validator is V5
        assertEq(kondux.DEFAULT_TRANSFER_VALIDATOR(), LB_VALIDATOR_V5);
        
        vm.prank(admin);
        kondux.setTransferValidator(LB_VALIDATOR_V5);
        
        assertEq(kondux.getTransferValidator(), LB_VALIDATOR_V5);
    }

    function test_EIP4907() public {
        vm.prank(minter);
        kondux.safeMint(user1, 1);

        uint64 expires = uint64(block.timestamp + 3600);
        
        vm.prank(user1);
        kondux.setUser(0, user2, expires);

        assertEq(kondux.userOf(0), user2);
        assertEq(kondux.userExpires(0), expires);

        // Fast forward
        vm.warp(block.timestamp + 3601);
        assertEq(kondux.userOf(0), address(0));
    }
}
