// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ISeaport {
    enum OrderType {
        FULL_OPEN,
        PARTIAL_OPEN,
        FULL_RESTRICTED,
        PARTIAL_RESTRICTED,
        CONTRACT
    }

    enum ItemType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155,
        ERC721_WITH_CRITERIA,
        ERC1155_WITH_CRITERIA
    }

    struct OfferItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }

    struct ConsiderationItem {
        ItemType itemType;
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
        OrderType orderType;
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
        OrderType orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 totalOriginalConsiderationItems;
    }

    struct Order {
        OrderParameters parameters;
        bytes signature;
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

contract SeaportHelper {
    ISeaport public constant SEAPORT = ISeaport(0x0000000000000068F116a894984e2DB1123eB395);

    struct OfferParams {
        address offerer;
        address offerToken;
        uint256 offerTokenId; // 0 for ERC20
        uint256 offerAmount;
        ISeaport.ItemType offerItemType;
        address considerationToken;
        uint256 considerationTokenId; // 0 for ERC20
        uint256 considerationAmount;
        ISeaport.ItemType considerationItemType;
        address recipient;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
    }

    /**
     * @notice Prepares the OrderComponents struct needed for signing or validation.
     *         Fetches the current counter from Seaport.
     */
    function prepareOffer(OfferParams memory params) external view returns (ISeaport.OrderComponents memory components) {
        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: params.offerItemType,
            token: params.offerToken,
            identifierOrCriteria: params.offerTokenId,
            startAmount: params.offerAmount,
            endAmount: params.offerAmount
        });

        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](1);
        consideration[0] = ISeaport.ConsiderationItem({
            itemType: params.considerationItemType,
            token: params.considerationToken,
            identifierOrCriteria: params.considerationTokenId,
            startAmount: params.considerationAmount,
            endAmount: params.considerationAmount,
            recipient: payable(params.recipient)
        });

        uint256 counter = SEAPORT.getCounter(params.offerer);

        components = ISeaport.OrderComponents({
            offerer: params.offerer,
            zone: address(0),
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_OPEN,
            startTime: params.startTime,
            endTime: params.endTime,
            zoneHash: params.zoneHash,
            salt: params.salt,
            conduitKey: params.conduitKey,
            counter: counter
        });
    }

    /**
     * @notice Prepares an OrderComponents struct for a standard NFT sale with royalties.
     *         Assumes Native ETH payment.
     */
    function prepareOrderWithRoyalties(
        address offerer,
        address collection,
        uint256 tokenId,
        uint256 price,
        address royaltyReceiver,
        uint256 royaltyAmount,
        uint256 startTime,
        uint256 endTime
    ) external view returns (ISeaport.OrderComponents memory components) {
        // Use the version with OpenSea fee defaulting to 0 (for non-OpenSea usage)
        return prepareOrderForOpenSea(
            offerer,
            collection,
            tokenId,
            price,
            royaltyReceiver,
            royaltyAmount,
            address(0), // No OpenSea fee recipient
            0,          // No OpenSea fee
            bytes32(0), // Default conduit key
            startTime,
            endTime
        );
    }

    /**
     * @notice OpenSea-compatible order preparation with platform fee support.
     * @param offerer The seller address
     * @param collection The NFT collection address
     * @param tokenId The token ID to sell
     * @param price Total sale price in wei
     * @param royaltyReceiver ERC2981 royalty receiver
     * @param royaltyAmount ERC2981 royalty amount
     * @param openseaFeeRecipient OpenSea fee recipient (usually 0x0000a26b00c1F0DF003000390027140000fAa719)
     * @param openseaFeeAmount OpenSea fee amount (usually 2.5% = price * 250 / 10000)
     * @param conduitKey OpenSea conduit key for approvals
     * @param startTime Order start timestamp
     * @param endTime Order end timestamp
     */
    function prepareOrderForOpenSea(
        address offerer,
        address collection,
        uint256 tokenId,
        uint256 price,
        address royaltyReceiver,
        uint256 royaltyAmount,
        address openseaFeeRecipient,
        uint256 openseaFeeAmount,
        bytes32 conduitKey,
        uint256 startTime,
        uint256 endTime
    ) public view returns (ISeaport.OrderComponents memory components) {
        // Offer: 1 NFT
        ISeaport.OfferItem[] memory offer = new ISeaport.OfferItem[](1);
        offer[0] = ISeaport.OfferItem({
            itemType: ISeaport.ItemType.ERC721,
            token: collection,
            identifierOrCriteria: tokenId,
            startAmount: 1,
            endAmount: 1
        });

        // Count consideration items (seller + optional royalty + optional opensea fee)
        uint256 considerationCount = 1;
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            considerationCount++;
        }
        if (openseaFeeAmount > 0 && openseaFeeRecipient != address(0)) {
            considerationCount++;
        }

        ISeaport.ConsiderationItem[] memory consideration = new ISeaport.ConsiderationItem[](considerationCount);
        
        // Calculate seller amount (price - royalty - opensea fee)
        uint256 sellerAmount = price - royaltyAmount - openseaFeeAmount;
        
        uint256 idx = 0;
        
        // 1. Net to Seller (always first)
        consideration[idx] = ISeaport.ConsiderationItem({
            itemType: ISeaport.ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: sellerAmount,
            endAmount: sellerAmount,
            recipient: payable(offerer)
        });
        idx++;

        // 2. OpenSea Fee (if applicable) - OpenSea expects their fee before royalties
        if (openseaFeeAmount > 0 && openseaFeeRecipient != address(0)) {
            consideration[idx] = ISeaport.ConsiderationItem({
                itemType: ISeaport.ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: openseaFeeAmount,
                endAmount: openseaFeeAmount,
                recipient: payable(openseaFeeRecipient)
            });
            idx++;
        }

        // 3. Royalty (if applicable)
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            consideration[idx] = ISeaport.ConsiderationItem({
                itemType: ISeaport.ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: royaltyAmount,
                endAmount: royaltyAmount,
                recipient: payable(royaltyReceiver)
            });
        }

        uint256 counter = SEAPORT.getCounter(offerer);

        components = ISeaport.OrderComponents({
            offerer: offerer,
            zone: address(0),
            offer: offer,
            consideration: consideration,
            orderType: ISeaport.OrderType.FULL_OPEN,
            startTime: startTime,
            endTime: endTime,
            zoneHash: bytes32(0),
            salt: uint256(keccak256(abi.encodePacked(offerer, block.timestamp, tokenId))),
            conduitKey: conduitKey,
            counter: counter
        });
    }

    /**
     * @notice Validates an order on-chain. This effectively "posts" the order if the caller is the offerer.
     */
    function createOrderOnChain(ISeaport.OrderComponents calldata components) external returns (bool) {
        ISeaport.OrderComponents[] memory orders = new ISeaport.OrderComponents[](1);
        orders[0] = components;
        return SEAPORT.validate(orders);
    }

    /**
     * @notice Settles a deal by fulfilling an order.
     *         Caller must have approved Seaport to spend the consideration tokens (if ERC20/721).
     *         If consideration is Native (ETH), value must be sent.
     *         Uses fulfillAdvancedOrder to ensure the caller receives the offer items.
     */
    function settleDeal(ISeaport.Order calldata order, bytes32 fulfillerConduitKey) external payable returns (bool) {
        // Convert to AdvancedOrder to specify recipient
        ISeaport.AdvancedOrder memory advancedOrder = ISeaport.AdvancedOrder({
            parameters: order.parameters,
            numerator: 1,
            denominator: 1,
            signature: order.signature,
            extraData: ""
        });
        
        ISeaport.CriteriaResolver[] memory criteriaResolvers = new ISeaport.CriteriaResolver[](0);
        
        return SEAPORT.fulfillAdvancedOrder{value: msg.value}(
            advancedOrder, 
            criteriaResolvers, 
            fulfillerConduitKey, 
            msg.sender // Recipient is the caller (Buyer)
        );
    }

    /**
     * @notice Settles a deal using advanced order (useful for partial fills or criteria).
     */
    function settleDealAdvanced(
        ISeaport.AdvancedOrder calldata advancedOrder,
        ISeaport.CriteriaResolver[] calldata criteriaResolvers,
        bytes32 fulfillerConduitKey,
        address recipient
    ) external payable returns (bool) {
        return SEAPORT.fulfillAdvancedOrder{value: msg.value}(advancedOrder, criteriaResolvers, fulfillerConduitKey, recipient);
    }
}
