// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxBatchMinter.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxBeaconFactory.sol";
import "../contracts/tests/AuthorityMock.sol";
import "../contracts/tests/MockKondux.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title KonduxBatchMinter Tests
 * @notice Forge tests for the KonduxBatchMinter - EIP-712 signed batch minting
 * @dev Migrated from test/KonduxBatchMinter.test.js
 */
contract KonduxBatchMinterTest is Test {
    KonduxBatchMinter public batchMinter;
    KonduxImplementation public kondux;
    KonduxBeaconFactory public factory;
    AuthorityMock public authority;

    address public deployer;
    address public admin;
    address public minter;
    address public user1;
    address public user2;
    address public treasury;

    uint256 public deployerPrivateKey;
    uint256 public minterPrivateKey;
    uint256 public user1PrivateKey;

    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant BATCH_MINTER_ROLE = keccak256("BATCH_MINTER_ROLE");
    bytes32 constant DNA_MODIFIER_ROLE = keccak256("DNA_MODIFIER_ROLE");

    // EIP-712 type hash
    bytes32 constant MINT_TYPEHASH = keccak256(
        "MintAuthorisation(address recipient,bytes32 dnasHash,uint256 nonce,uint256 deadline,uint256 priceWei)"
    );

    function setUp() public {
        // Create deterministic private keys for signers
        deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        minterPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        user1PrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

        deployer = vm.addr(deployerPrivateKey);
        minter = vm.addr(minterPrivateKey);
        user1 = vm.addr(user1PrivateKey);
        user2 = makeAddr("user2");
        admin = makeAddr("admin");
        treasury = makeAddr("treasury");

        vm.deal(deployer, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Deploy infrastructure
        vm.startPrank(deployer);

        // Deploy implementation
        KonduxImplementation impl = new KonduxImplementation();

        // Deploy factory with beacon
        factory = new KonduxBeaconFactory(address(impl));

        // Deploy a clone via factory
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "KonduxNFT",
            "kNFT",
            0, // maxSupply (unlimited)
            deployer, // initialAdmin
            address(factory) // factory
        );

        (address proxyAddr, ) = factory.deployCloneWithSplitter(
            initData,
            false, // no splitter for this test
            address(0), // partnerWallet
            0, // manufacturerCutBP
            0, // partnerCutBP
            0, // defaultCreatorCutBP
            address(0) // defaultCreatorWallet
        );

        kondux = KonduxImplementation(payable(proxyAddr));

        // Deploy authority mock with treasury as vault
        authority = new AuthorityMock(treasury);

        // Deploy batch minter
        batchMinter = new KonduxBatchMinter(address(kondux), address(authority));

        // Grant MINTER_ROLE to batch minter on kondux
        kondux.grantRole(MINTER_ROLE, address(batchMinter));

        // Grant roles to admin
        kondux.grantRole(kondux.DEFAULT_ADMIN_ROLE(), admin);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function test_deployment() public view {
        assertEq(address(batchMinter.kondux()), address(kondux));
        assertEq(address(batchMinter.authority()), address(authority));
        assertFalse(batchMinter.paused());
    }

    function test_deployerHasRoles() public view {
        assertTrue(batchMinter.hasRole(batchMinter.DEFAULT_ADMIN_ROLE(), deployer));
        assertTrue(batchMinter.hasRole(BATCH_MINTER_ROLE, deployer));
    }

    /*//////////////////////////////////////////////////////////////
                        HAPPY PATH - MINTING
    //////////////////////////////////////////////////////////////*/

    function test_mintBatchWithValidSignature() public {
        uint256[] memory dnas = new uint256[](3);
        dnas[0] = 111;
        dnas[1] = 222;
        dnas[2] = 333;

        uint256 priceWei = 0.05 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        uint256 supplyBefore = kondux.totalSupply();
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(user1);
        batchMinter.mintBatchWithSignature{value: priceWei}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );

        // Verify supply increased
        assertEq(kondux.totalSupply(), supplyBefore + dnas.length);
        assertEq(kondux.balanceOf(user1), dnas.length);

        // Verify ETH forwarded to treasury
        assertEq(treasury.balance, treasuryBalanceBefore + priceWei);

        // Verify nonce incremented
        assertEq(batchMinter.mintNonces(user1), 1);
    }

    function test_mintBatchEmitsEvent() public {
        uint256[] memory dnas = new uint256[](2);
        dnas[0] = 100;
        dnas[1] = 200;

        uint256 priceWei = 0.01 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit KonduxBatchMinter.AuthorisedMint(deployer, user1, dnas, priceWei);
        batchMinter.mintBatchWithSignature{value: priceWei}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );
    }

    function test_mintBatchWithZeroPrice() public {
        uint256[] memory dnas = new uint256[](1);
        dnas[0] = 42;

        uint256 priceWei = 0;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        vm.prank(user1);
        batchMinter.mintBatchWithSignature{value: 0}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );

        assertEq(kondux.balanceOf(user1), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTH FAILURES
    //////////////////////////////////////////////////////////////*/

    function test_revertsIfSignerLacksBatchMinterRole() public {
        // Revoke BATCH_MINTER_ROLE from deployer
        vm.prank(deployer);
        batchMinter.revokeRole(BATCH_MINTER_ROLE, deployer);

        uint256[] memory dnas = new uint256[](1);
        dnas[0] = 42;

        uint256 priceWei = 0;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        // Sign with user2 who doesn't have BATCH_MINTER_ROLE
        bytes memory sig = _signAuth(
            user1PrivateKey, // user1 doesn't have BATCH_MINTER_ROLE
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectRevert("kNFT: signer lacks BATCH_MINTER_ROLE");
        batchMinter.mintBatchWithSignature{value: 0}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );
    }

    function test_revertsOnExpiredDeadline() public {
        // Warp to a reasonable timestamp first to avoid underflow
        vm.warp(1000);

        uint256[] memory dnas = new uint256[](1);
        dnas[0] = 7;

        uint256 priceWei = 0.01 ether;
        uint256 nonce = 0;
        uint256 pastDeadline = block.timestamp - 10; // expired

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            pastDeadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectRevert("kNFT: auth expired");
        batchMinter.mintBatchWithSignature{value: priceWei}(
            user1,
            dnas,
            pastDeadline,
            priceWei,
            nonce,
            sig
        );
    }

    function test_revertsOnWrongETH() public {
        uint256[] memory dnas = new uint256[](1);
        dnas[0] = 7;

        uint256 priceWei = 0.01 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectRevert("kNFT: wrong ETH");
        batchMinter.mintBatchWithSignature{value: 0}( // sending 0 but signed for 0.01 ether
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );
    }

    function test_revertsOnBadNonce() public {
        uint256[] memory dnas = new uint256[](1);
        dnas[0] = 7;

        uint256 priceWei = 0.01 ether;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        // First mint succeeds
        vm.prank(user1);
        batchMinter.mintBatchWithSignature{value: priceWei}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );

        // Second mint with same nonce fails
        bytes memory sig2 = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce, // same nonce
            deadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectRevert("kNFT: bad nonce");
        batchMinter.mintBatchWithSignature{value: priceWei}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce, // reusing nonce 0
            sig2
        );
    }

    function test_revertsOnEmptyDNAs() public {
        uint256[] memory dnas = new uint256[](0);

        uint256 priceWei = 0;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectRevert("kNFT: no DNAs");
        batchMinter.mintBatchWithSignature{value: 0}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function test_revertsWhenPaused() public {
        vm.prank(deployer);
        batchMinter.setPaused(true);
        assertTrue(batchMinter.paused());

        uint256[] memory dnas = new uint256[](1);
        dnas[0] = 1;

        uint256 priceWei = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            0,
            deadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectRevert("kNFT: paused");
        batchMinter.mintBatchWithSignature{value: 0}(
            user1,
            dnas,
            deadline,
            priceWei,
            0,
            sig
        );
    }

    /*//////////////////////////////////////////////////////////////
                        VAULT ZERO CHECK
    //////////////////////////////////////////////////////////////*/

    function test_revertsIfVaultZero() public {
        // Deploy new authority with zero vault
        AuthorityMock zeroVaultAuth = new AuthorityMock(address(0));

        // Deploy new batch minter with zero vault authority
        vm.startPrank(deployer);
        KonduxBatchMinter newBatch = new KonduxBatchMinter(address(kondux), address(zeroVaultAuth));
        kondux.grantRole(MINTER_ROLE, address(newBatch));
        vm.stopPrank();

        uint256[] memory dnas = new uint256[](1);
        dnas[0] = 99;

        uint256 priceWei = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuthForContract(
            deployerPrivateKey,
            address(newBatch),
            user1,
            dnas,
            0,
            deadline,
            priceWei
        );

        vm.prank(user1);
        vm.expectRevert("kNFT: vault zero");
        newBatch.mintBatchWithSignature{value: 0}(
            user1,
            dnas,
            deadline,
            priceWei,
            0,
            sig
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_setKNFT() public {
        MockKondux newKondux = new MockKondux();

        address oldAddr = address(batchMinter.kondux());

        vm.prank(deployer);
        vm.expectEmit(true, true, false, false);
        emit KonduxBatchMinter.KonduxTargetUpdated(oldAddr, address(newKondux));
        batchMinter.setKNFT(address(newKondux));

        assertEq(address(batchMinter.kondux()), address(newKondux));
    }

    function test_setKNFT_revertsForNonAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        batchMinter.setKNFT(address(1));
    }

    function test_setKNFT_revertsForZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert("Kondux addr zero");
        batchMinter.setKNFT(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        LARGE BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_mintBatch50NFTs() public {
        uint256[] memory dnas = _buildDnas(50, 1);
        uint256 priceWei = 0;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        vm.prank(user1);
        batchMinter.mintBatchWithSignature{value: 0}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );

        assertEq(kondux.balanceOf(user1), 50);
    }

    function test_mintBatch150NFTs() public {
        uint256[] memory dnas = _buildDnas(150, 1);
        uint256 priceWei = 0;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 3600;

        bytes memory sig = _signAuth(
            deployerPrivateKey,
            user1,
            dnas,
            nonce,
            deadline,
            priceWei
        );

        vm.prank(user1);
        batchMinter.mintBatchWithSignature{value: 0}(
            user1,
            dnas,
            deadline,
            priceWei,
            nonce,
            sig
        );

        assertEq(kondux.balanceOf(user1), 150);
    }

    function test_mintMultipleBatches() public {
        uint256 batchIterations = 5;
        uint256 batchSize = 100;

        for (uint256 i = 0; i < batchIterations; i++) {
            uint256[] memory dnas = _buildDnas(batchSize, i * batchSize + 1);
            uint256 nonce = batchMinter.mintNonces(user1);
            uint256 deadline = block.timestamp + 3600;

            bytes memory sig = _signAuth(
                deployerPrivateKey,
                user1,
                dnas,
                nonce,
                deadline,
                0
            );

            vm.prank(user1);
            batchMinter.mintBatchWithSignature{value: 0}(
                user1,
                dnas,
                deadline,
                0,
                nonce,
                sig
            );
        }

        assertEq(kondux.balanceOf(user1), batchSize * batchIterations);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _buildDnas(uint256 count, uint256 base) internal pure returns (uint256[] memory) {
        uint256[] memory dnas = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            dnas[i] = base + i;
        }
        return dnas;
    }

    function _signAuth(
        uint256 signerPrivateKey,
        address recipient,
        uint256[] memory dnas,
        uint256 nonce,
        uint256 deadline,
        uint256 priceWei
    ) internal view returns (bytes memory) {
        return _signAuthForContract(
            signerPrivateKey,
            address(batchMinter),
            recipient,
            dnas,
            nonce,
            deadline,
            priceWei
        );
    }

    function _signAuthForContract(
        uint256 signerPrivateKey,
        address verifyingContract,
        address recipient,
        uint256[] memory dnas,
        uint256 nonce,
        uint256 deadline,
        uint256 priceWei
    ) internal view returns (bytes memory) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Kondux kNFT")),
                keccak256(bytes("1")),
                block.chainid,
                verifyingContract
            )
        );

        bytes32 dnasHash = keccak256(abi.encodePacked(dnas));
        bytes32 structHash = keccak256(
            abi.encode(
                MINT_TYPEHASH,
                recipient,
                dnasHash,
                nonce,
                deadline,
                priceWei
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
