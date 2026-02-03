// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IKonduxRoyaltySplitter {
    function collection() external view returns (address);
    function manufacturerWallet() external view returns (address);
    function partnerWallet() external view returns (address);
    function manufacturerCutBP() external view returns (uint96);
    function partnerCutBP() external view returns (uint96);
    function defaultCreatorCutBP() external view returns (uint96);
    function pushModeEnabled() external view returns (bool);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function COLLECTION_ROLE() external view returns (bytes32);
    function ADMIN_ROLE() external view returns (bytes32);
    function pendingETHAmount() external view returns (uint256);
}

interface IKonduxImplementation {
    function royaltySplitter() external view returns (address);
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
    function setRoyaltySplitter(address splitter) external;
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
}

contract CheckSplitterConfig is Test {
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;
    address constant OLD_SPLITTER = 0xf2E21db6Bee5797A9c9A38c4653bcB81a2695227;
    address constant NEW_SPLITTER = 0x29272821e851b46614bA174481Fe8cFE658Bfd7A;
    
    function setUp() public {
        string memory rpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(rpc);
    }
    
    function test_compareOldAndNewSplitter() public view {
        IKonduxImplementation collection = IKonduxImplementation(COLLECTION);
        IKonduxRoyaltySplitter oldSplitter = IKonduxRoyaltySplitter(OLD_SPLITTER);
        IKonduxRoyaltySplitter newSplitter = IKonduxRoyaltySplitter(NEW_SPLITTER);
        
        console2.log("=== Collection State ===");
        console2.log("collection.royaltySplitter():", collection.royaltySplitter());
        (address royaltyReceiver, uint256 royaltyAmount) = collection.royaltyInfo(6, 1 ether);
        console2.log("ERC2981 royaltyInfo receiver:", royaltyReceiver);
        console2.log("ERC2981 royaltyInfo amount:", royaltyAmount);
        
        console2.log("");
        console2.log("=== OLD Splitter (0xf2e2...5227) ===");
        console2.log("ETH balance:", OLD_SPLITTER.balance);
        console2.log("pendingETHAmount:", oldSplitter.pendingETHAmount());
        console2.log("collection():", oldSplitter.collection());
        console2.log("manufacturerWallet:", oldSplitter.manufacturerWallet());
        console2.log("partnerWallet:", oldSplitter.partnerWallet());
        console2.log("manufacturerCutBP:", oldSplitter.manufacturerCutBP());
        console2.log("partnerCutBP:", oldSplitter.partnerCutBP());
        console2.log("defaultCreatorCutBP:", oldSplitter.defaultCreatorCutBP());
        console2.log("pushModeEnabled:", oldSplitter.pushModeEnabled() ? 1 : 0);
        
        bytes32 collectionRole = oldSplitter.COLLECTION_ROLE();
        console2.log("COLLECTION has COLLECTION_ROLE:", oldSplitter.hasRole(collectionRole, COLLECTION) ? 1 : 0);
        
        console2.log("");
        console2.log("=== NEW Splitter (0x2927...Bfd7A) ===");
        console2.log("ETH balance:", NEW_SPLITTER.balance);
        console2.log("pendingETHAmount:", newSplitter.pendingETHAmount());
        console2.log("collection():", newSplitter.collection());
        console2.log("manufacturerWallet:", newSplitter.manufacturerWallet());
        console2.log("partnerWallet:", newSplitter.partnerWallet());
        console2.log("manufacturerCutBP:", newSplitter.manufacturerCutBP());
        console2.log("partnerCutBP:", newSplitter.partnerCutBP());
        console2.log("defaultCreatorCutBP:", newSplitter.defaultCreatorCutBP());
        console2.log("pushModeEnabled:", newSplitter.pushModeEnabled() ? 1 : 0);
        
        bytes32 collectionRole2 = newSplitter.COLLECTION_ROLE();
        console2.log("COLLECTION has COLLECTION_ROLE:", newSplitter.hasRole(collectionRole2, COLLECTION) ? 1 : 0);
        
        console2.log("");
        console2.log("=== Recommendation ===");
        if (collection.royaltySplitter() == NEW_SPLITTER && royaltyReceiver == NEW_SPLITTER) {
            console2.log("Both royaltySplitter() and ERC2981 point to NEW splitter.");
            console2.log("To revert to OLD splitter:");
            console2.log("1. Call setRoyaltySplitter(OLD_SPLITTER) - changes where registerSale goes");
            console2.log("2. Call setDefaultRoyalty(OLD_SPLITTER, totalBP) - changes ERC2981 receiver");
        }
    }
}
