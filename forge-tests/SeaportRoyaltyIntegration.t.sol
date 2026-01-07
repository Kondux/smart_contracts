// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxBeaconFactory.sol";
import "../contracts/helpers/SeaportHelper.sol";

contract SeaportRoyaltyIntegrationTest is Test {
    KonduxImplementation public kondux;
    KonduxBeaconFactory public factory;
    SeaportHelper public helper;

    uint256 public sellerPk = 0xA11CE;
    uint256 public buyerPk = 0xB0B;
    address public deployer = address(0x1);
    address public admin = address(0x2);
    address public minter = address(0x3);
    address public seller;
    address public buyer;
    address public partner = address(0x5);

    // Seaport 1.6 on Mainnet
    address public constant SEAPORT_1_6 = 0x0000000000000068F116a894984e2DB1123eB395;

    // Seaport Type Hashes
    bytes32 constant OFFER_ITEM_TYPEHASH = keccak256("OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");
    bytes32 constant CONSIDERATION_ITEM_TYPEHASH = keccak256("ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)");
    bytes32 constant ORDER_COMPONENTS_TYPEHASH = keccak256("OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 counter)ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");

    function setUp() public {
        seller = vm.addr(sellerPk);
        buyer = vm.addr(buyerPk);

        // Fork Mainnet
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);

        vm.startPrank(deployer);

        // Deploy Implementation & Factory
        KonduxImplementation impl = new KonduxImplementation();
        factory = new KonduxBeaconFactory(address(impl));

        // Deploy SeaportHelper
        helper = new SeaportHelper();

        // Deploy Clone
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "KonduxNFT", "kNFT", 1000, admin, address(factory), address(0)
        );

        address cloneAddr = factory.deployClone(initData);
        kondux = KonduxImplementation(payable(cloneAddr));
        vm.stopPrank();

        // Setup Roles & Config
        vm.startPrank(admin);
        kondux.grantRole(kondux.MINTER_ROLE(), minter);
        
        // Configure Default Security Policy (Whitelists Seaport)
        kondux.setToDefaultSecurityPolicy();
        
        // Configure Royalties (5% Total)
        kondux.setPartnerWallet(partner);
        kondux.setRoyaltySplits(200, 150, 150); // 500 bps = 5%
        vm.stopPrank();

        // Mint token to seller
        vm.prank(minter);
        kondux.safeMint(seller, 1);
    }

    function test_SeaportRoyaltyPayment() public {
        uint256 tokenId = 0;
        uint256 price = 1 ether;

        // 1. Get Royalty Info
        (address royaltyReceiver, uint256 royaltyAmount) = kondux.royaltyInfo(tokenId, price);
        uint256 sellerAmount = price - royaltyAmount;

        assertEq(royaltyReceiver, partner, "Royalty receiver should be partner");
        assertEq(royaltyAmount, 0.05 ether, "Royalty amount should be 5%");

        // 2. Seller approves Seaport
        vm.prank(seller);
        kondux.setApprovalForAll(SEAPORT_1_6, true);

        // 3. Prepare Offer using Helper
        ISeaport.OrderComponents memory components = helper.prepareOrderWithRoyalties(
            seller,
            address(kondux),
            tokenId,
            price,
            royaltyReceiver,
            royaltyAmount,
            block.timestamp,
            block.timestamp + 1000
        );

        // 4. Sign Order (Seller)
        bytes memory signature = _signOrder(sellerPk, components);

        // 5. Construct Order
        ISeaport.Order memory order = ISeaport.Order({
            parameters: _componentsToParameters(components),
            signature: signature
        });

        // 6. Execute Trade (Buyer)
        vm.deal(buyer, 10 ether);
        uint256 sellerBalanceBefore = seller.balance;
        uint256 partnerBalanceBefore = partner.balance;

        vm.prank(buyer);
        // Buyer calls SeaportHelper to settle the deal
        helper.settleDeal{value: price}(order, bytes32(0));

        // 7. Verify Outcomes
        assertEq(kondux.ownerOf(tokenId), buyer, "Buyer should own the NFT");
        assertEq(seller.balance, sellerBalanceBefore + sellerAmount, "Seller should receive 95%");
        assertEq(partner.balance, partnerBalanceBefore + royaltyAmount, "Partner should receive 5% royalty");
    }

    // --- Helper Functions for Signing ---

    function _componentsToParameters(ISeaport.OrderComponents memory components) internal pure returns (ISeaport.OrderParameters memory) {
        return ISeaport.OrderParameters({
            offerer: components.offerer,
            zone: components.zone,
            offer: components.offer,
            consideration: components.consideration,
            orderType: components.orderType,
            startTime: components.startTime,
            endTime: components.endTime,
            zoneHash: components.zoneHash,
            salt: components.salt,
            conduitKey: components.conduitKey,
            totalOriginalConsiderationItems: components.consideration.length
        });
    }

    function _signOrder(uint256 pk, ISeaport.OrderComponents memory components) internal view returns (bytes memory) {
        bytes32 orderHash = _getOrderHash(components);
        (, bytes32 domainSeparator, ) = ISeaport(SEAPORT_1_6).information();
        
        bytes32 digest = keccak256(abi.encodePacked(
            bytes2(0x1901),
            domainSeparator,
            orderHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getOrderHash(ISeaport.OrderComponents memory components) internal pure returns (bytes32) {
        bytes32[] memory offerHashes = new bytes32[](components.offer.length);
        for (uint256 i = 0; i < components.offer.length; ++i) {
            offerHashes[i] = _hashOfferItem(components.offer[i]);
        }

        bytes32[] memory considerationHashes = new bytes32[](components.consideration.length);
        for (uint256 i = 0; i < components.consideration.length; ++i) {
            considerationHashes[i] = _hashConsiderationItem(components.consideration[i]);
        }

        return keccak256(abi.encode(
            ORDER_COMPONENTS_TYPEHASH,
            components.offerer,
            components.zone,
            _hashArray(offerHashes),
            _hashArray(considerationHashes),
            components.orderType,
            components.startTime,
            components.endTime,
            components.zoneHash,
            components.salt,
            components.conduitKey,
            components.counter
        ));
    }

    function _hashOfferItem(ISeaport.OfferItem memory item) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OFFER_ITEM_TYPEHASH,
            item.itemType,
            item.token,
            item.identifierOrCriteria,
            item.startAmount,
            item.endAmount
        ));
    }

    function _hashConsiderationItem(ISeaport.ConsiderationItem memory item) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CONSIDERATION_ITEM_TYPEHASH,
            item.itemType,
            item.token,
            item.identifierOrCriteria,
            item.startAmount,
            item.endAmount,
            item.recipient
        ));
    }

    function _hashArray(bytes32[] memory hashes) internal pure returns (bytes32) {
        bytes memory packed = new bytes(hashes.length * 32);
        for (uint256 i = 0; i < hashes.length; i++) {
            bytes32 hash = hashes[i];
            assembly {
                mstore(add(packed, add(32, mul(i, 32))), hash)
            }
        }
        return keccak256(packed);
    }
}
