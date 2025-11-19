// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/KonduxImplementation.sol";
import "../contracts/KonduxBeaconFactory.sol";
import "../contracts/interfaces/ICreatorTokenTransferValidator.sol";

// Minimal interface for Seaport 1.6
interface ISeaport {
    struct OfferItem {
        uint8 itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }

    struct ConsiderationItem {
        uint8 itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address payable recipient;
    }

    struct OrderComponents {
        address offerer;
        address zone;
        OfferItem[] offer;
        ConsiderationItem[] consideration;
        uint8 orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 counter;
    }

    struct OrderParameters {
        address offerer;
        address zone;
        OfferItem[] offer;
        ConsiderationItem[] consideration;
        uint8 orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 totalOriginalConsiderationItems;
    }

    struct AdvancedOrder {
        OrderParameters parameters;
        uint120 numerator;
        uint120 denominator;
        bytes signature;
        bytes extraData;
    }

    struct CriteriaResolver {
        uint256 orderIndex;
        uint8 side;
        uint256 index;
        uint256 identifier;
        bytes32[] criteriaProof;
    }

    struct Order {
        OrderParameters parameters;
        bytes signature;
    }

    function fulfillOrder(Order calldata order, bytes32 fulfillerConduitKey) external payable returns (bool fulfilled);

    function fulfillAdvancedOrder(
        AdvancedOrder calldata advancedOrder,
        CriteriaResolver[] calldata criteriaResolvers,
        bytes32 fulfillerConduitKey,
        address recipient
    ) external payable returns (bool fulfilled);

    function validate(OrderComponents[] calldata orders) external returns (bool validated);
    function getCounter(address offerer) external view returns (uint256 counter);
    function getOrderHash(OrderComponents calldata components) external view returns (bytes32);
    function information() external view returns (string memory version, bytes32 domainSeparator, address conduitController);
}

contract KonduxRoyaltyTest is Test {
    KonduxImplementation public kondux;
    KonduxBeaconFactory public factory;
    
    uint256 public sellerPk = 0xA11CE;
    address public deployer = address(0x100);
    address public admin = address(0x101);
    address public minter = address(0x102);
    address public seller;
    address public buyer = address(0x104);
    address public partner = address(0x105);
    
    // Seaport 1.6 on Mainnet
    address public constant SEAPORT_1_6 = 0x0000000000000068F116a894984e2DB1123eB395;
    
    // Seaport Type Hashes
    bytes32 constant OFFER_ITEM_TYPEHASH = keccak256("OfferItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount)");
    bytes32 constant CONSIDERATION_ITEM_TYPEHASH = keccak256("ConsiderationItem(uint8 itemType,address token,uint256 identifierOrCriteria,uint256 startAmount,uint256 endAmount,address recipient)");
    bytes32 constant ORDER_COMPONENTS_TYPEHASH = keccak256("OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 counter)");

    function setUp() public {
        seller = vm.addr(sellerPk);
        
        // Fork Mainnet
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string("https://eth.merkle.io"));
        vm.createSelectFork(rpcUrl);
        
        vm.startPrank(deployer);
        
        // Deploy Implementation & Factory
        KonduxImplementation impl = new KonduxImplementation();
        factory = new KonduxBeaconFactory(address(impl));
        
        // Deploy Clone
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "KonduxNFT", "kNFT", 1000, admin
        );
        
        address cloneAddr = factory.deployClone(initData);
        kondux = KonduxImplementation(payable(cloneAddr));
        
        // Setup Roles
        // Note: admin is already set via initialize
        vm.stopPrank();

        vm.startPrank(admin);
        kondux.grantRole(kondux.MINTER_ROLE(), minter);
        
        // Configure Default Security Policy (Whitelists Seaport)
        kondux.setToDefaultSecurityPolicy();
        
        // Configure Royalties (5% Total)
        // 2% Manufacturer, 1.5% Partner, 1.5% Creator
        kondux.setPartnerWallet(partner);
        kondux.setRoyaltySplits(200, 150, 150); 
        vm.stopPrank();
        
        // Mint token to seller
        vm.prank(minter);
        kondux.safeMint(seller, 12345);
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

    function _signOrder(uint256 pk, ISeaport.OrderComponents memory components) internal view returns (bytes memory) {
        bytes32 orderHash = ISeaport(SEAPORT_1_6).getOrderHash(components);
        (, bytes32 domainSeparator, ) = ISeaport(SEAPORT_1_6).information();
        
        bytes32 digest = keccak256(abi.encodePacked(
            bytes2(0x1901),
            domainSeparator,
            orderHash
        ));
        
        console.log("Digest (calculated):");
        console.logBytes32(digest);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    
    function test_RoyaltyInfo() public view {
        // Check royalty info for 1 ETH sale
        uint256 salePrice = 1 ether;
        (address receiver, uint256 amount) = kondux.royaltyInfo(0, salePrice);
        
        // Expect 5% royalty (500 basis points) going to partner
        assertEq(receiver, partner);
        assertEq(amount, 0.05 ether); 
    }
    
    function test_SeaportTrade_Simulation() public {
        // 1. Approve Seaport to spend seller's NFT
        vm.prank(seller);
        kondux.setApprovalForAll(SEAPORT_1_6, true);
        
        // 2. Get Royalty Info
        uint256 price = 1 ether;
        (address royaltyReceiver, uint256 royaltyAmount) = kondux.royaltyInfo(0, price);
        
        uint256 sellerAmount = price - royaltyAmount;
        
        // Verify Royalty Calculation
        assertEq(royaltyReceiver, partner);
        assertEq(royaltyAmount, 0.05 ether); // 5%
        
        // 3. Simulate Seaport Execution
        // Seaport would:
        // a. Transfer NFT from Seller to Buyer
        // b. Transfer ETH from Buyer to Seller and Royalty Receiver
        
        vm.deal(buyer, 10 ether);
        uint256 sellerBalanceBefore = seller.balance;
        uint256 partnerBalanceBefore = partner.balance;
        
        // a. Transfer NFT (Prank Seaport)
        vm.prank(SEAPORT_1_6);
        kondux.transferFrom(seller, buyer, 0); // Token ID is 0
        
        // b. Transfer ETH (Simulate Payment)
        vm.prank(buyer);
        payable(seller).transfer(sellerAmount);
        
        vm.prank(buyer);
        payable(royaltyReceiver).transfer(royaltyAmount);
        
        // 4. Verify Outcomes
        assertEq(kondux.ownerOf(0), buyer, "Buyer should own the NFT");
        assertEq(seller.balance, sellerBalanceBefore + sellerAmount, "Seller should receive 95%");
        assertEq(partner.balance, partnerBalanceBefore + royaltyAmount, "Partner should receive 5% royalty");
    }
    
    function test_EOA_Transfer() public {
        // EOA to EOA transfer should work even with Level 3 security (Operator Whitelist),
        // because Level 3 usually allows OTC (direct transfers where msg.sender == from).
        
        vm.prank(minter);
        kondux.safeMint(seller, 100);
        
        vm.prank(seller);
        kondux.transferFrom(seller, buyer, 0);
        
        assertEq(kondux.ownerOf(0), buyer);
    }

    function _createSeaportOrder(
        address _offerer,
        uint256 _pk,
        address _token,
        uint256 _tokenId,
        uint256 _price,
        address _royaltyReceiver,
        uint256 _royaltyAmount
    ) internal view returns (ISeaport.Order memory) {
        ISeaport seaport = ISeaport(SEAPORT_1_6);
        uint256 counter = seaport.getCounter(_offerer);
        
        // Offer: NFT
        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem(2, _token, _tokenId, 1, 1);
        
        // Consideration: ETH to Seller + ETH to Royalty
        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](2);
        consideration[0] = ISeaport.ConsiderationItem(0, address(0), 0, _price - _royaltyAmount, _price - _royaltyAmount, payable(_offerer));
        consideration[1] = ISeaport.ConsiderationItem(0, address(0), 0, _royaltyAmount, _royaltyAmount, payable(_royaltyReceiver));
        
        ISeaport.OrderComponents memory components = ISeaport.OrderComponents({
            offerer: _offerer,
            zone: address(0),
            offer: offer,
            consideration: consideration,
            orderType: 0, // FULL_OPEN
            startTime: block.timestamp,
            endTime: block.timestamp + 1000,
            zoneHash: bytes32(0),
            salt: 123,
            conduitKey: bytes32(0),
            counter: counter
        });
        
        bytes memory signature = _signOrder(_pk, components);
        
        return ISeaport.Order({
            parameters: ISeaport.OrderParameters({
                offerer: _offerer,
                zone: address(0),
                offer: offer,
                consideration: consideration,
                orderType: 0,
                startTime: block.timestamp,
                endTime: block.timestamp + 1000,
                zoneHash: bytes32(0),
                salt: 123,
                conduitKey: bytes32(0),
                totalOriginalConsiderationItems: 2
            }),
            signature: signature
        });
    }

    function test_SeaportWhitelistWorkflow() public {
        // 1. Deploy fresh clone
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "KonduxNFT_2", "kNFT2", 1000, admin
        );
        address cloneAddr = factory.deployClone(initData);
        KonduxImplementation kondux2 = KonduxImplementation(payable(cloneAddr));
        
        // Setup Roles
        vm.startPrank(admin);
        kondux2.grantRole(kondux2.MINTER_ROLE(), minter);
        // Set Royalty Splits (needed for final check)
        kondux2.setPartnerWallet(partner);
        kondux2.setRoyaltySplits(200, 150, 150); // 5% total
        vm.stopPrank();
        
        // Mint
        vm.prank(minter);
        kondux2.safeMint(seller, 999);
        uint256 tokenId = 0; // First token of this clone
        
        // 2. Configure Validator MANUALLY (Restrictive, no Seaport)
        address validatorAddr = kondux2.getTransferValidator();
        ICreatorTokenTransferValidator v = ICreatorTokenTransferValidator(validatorAddr);
        
        // Impersonate the clone to configure its own validator settings
        vm.startPrank(address(kondux2));
        
        // Create List
        uint48 listId = v.createList("Restricted List");
        
        // Apply List
        v.applyListToCollection(address(kondux2), listId);
        
        // Set Level 4 (Operator Whitelist)
        v.setRulesetOfCollection(address(kondux2), 4, address(0), 0, 0);
        
        vm.stopPrank();
        
        // 3. Attempt Seaport Trade (Should FAIL)
        vm.prank(seller);
        kondux2.setApprovalForAll(SEAPORT_1_6, true);
        
        // Prepare Seaport Order
        uint256 price = 1 ether;
        (address royaltyReceiver, uint256 royaltyAmount) = kondux2.royaltyInfo(tokenId, price);
        
        ISeaport.Order memory order = _createSeaportOrder(
            seller,
            sellerPk,
            address(kondux2),
            tokenId,
            price,
            royaltyReceiver,
            royaltyAmount
        );
        
        // Execute Trade (Should FAIL)
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        vm.expectRevert(); // Validator should block transfer
        ISeaport(SEAPORT_1_6).fulfillOrder{value: price}(order, bytes32(0));
        
        // 4. Whitelist Seaport
        vm.startPrank(address(kondux2));
        address[] memory accounts = new address[](1);
        accounts[0] = SEAPORT_1_6;
        v.addAccountsToList(listId, 1, accounts);
        vm.stopPrank();
        
        // 5. Attempt Seaport Trade (Should SUCCEED)
        uint256 partnerBalanceBefore = partner.balance;
        uint256 sellerBalanceBefore = seller.balance;
        
        vm.prank(buyer);
        ISeaport(SEAPORT_1_6).fulfillOrder{value: price}(order, bytes32(0));
        
        // 6. Verify
        uint256 sellerAmount = price - royaltyAmount;
        assertEq(kondux2.ownerOf(tokenId), buyer, "Buyer should own token");
        assertEq(partner.balance, partnerBalanceBefore + royaltyAmount, "Partner got royalty");
        assertEq(seller.balance, sellerBalanceBefore + sellerAmount, "Seller got payment");
    }

    function test_HelperFunctions() public {
        // 1. Deploy fresh clone
        bytes memory initData = abi.encodeWithSelector(
            KonduxImplementation.initialize.selector,
            "KonduxNFT_Helper", "kNFTH", 1000, admin
        );
        address cloneAddr = factory.deployClone(initData);
        KonduxImplementation k = KonduxImplementation(payable(cloneAddr));
        
        vm.startPrank(admin);
        
        // 2. Call setToDefaultSecurityPolicy
        k.setToDefaultSecurityPolicy();
        
        // Verify listId is set
        uint48 listId = k.listId();
        assertTrue(listId > 0, "List ID should be set");
        
        // 3. Test addAccountsToWhitelist
        address newOperator = address(0x999);
        address[] memory wlAccounts = new address[](1);
        wlAccounts[0] = newOperator;
        
        k.addAccountsToWhitelist(wlAccounts);
        
        // Verify newOperator works (we need to mint and try transfer)
        k.grantRole(k.MINTER_ROLE(), minter);
        vm.stopPrank();
        
        vm.prank(minter);
        uint256 tokenId = k.safeMint(seller, 555);
        
        vm.prank(seller);
        k.setApprovalForAll(newOperator, true);
        
        // Should succeed because newOperator is whitelisted (Level 4)
        vm.prank(newOperator);
        k.transferFrom(seller, buyer, tokenId);
        assertEq(k.ownerOf(tokenId), buyer);
        
        // 4. Test addAccountsToBlacklist
        // Note: In Level 4 (Whitelist), Blacklist might not be active for operators.
        // But we verify the function call works.
        vm.startPrank(admin);
        address badActor = address(0x666);
        address[] memory blAccounts = new address[](1);
        blAccounts[0] = badActor;
        
        k.addAccountsToBlacklist(blAccounts);
        vm.stopPrank();

        // 5. Test freezeAccounts
        vm.startPrank(admin);
        address frozenUser = address(0x777);
        address[] memory freezeList = new address[](1);
        freezeList[0] = frozenUser;
        
        k.freezeAccounts(freezeList);
        vm.stopPrank();
    }
}
