// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IKonduxImplementation {
    function setRoyaltySplitter(address splitter) external;
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
    function royaltySplitter() external view returns (address);
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
}

/**
 * @title RevertToOldSplitter
 * @notice Reverts the collection to use the old splitter for compatibility with existing OpenSea orders
 * @dev Run with: forge script scripts/solidity/utility/RevertToOldSplitter.s.sol --rpc-url mainnet --broadcast
 */
contract RevertToOldSplitterScript is Script {
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;
    address constant OLD_SPLITTER = 0xf2E21db6Bee5797A9c9A38c4653bcB81a2695227;
    address constant NEW_SPLITTER = 0x29272821e851b46614bA174481Fe8cFE658Bfd7A;
    
    uint96 constant TOTAL_ROYALTY_BP = 1000; // 10% (500 mfg + 0 partner + 500 creator)
    
    function run() external {
        IKonduxImplementation collection = IKonduxImplementation(COLLECTION);
        
        // Check current state
        console2.log("=== Current State ===");
        console2.log("royaltySplitter():", collection.royaltySplitter());
        (address currentReceiver,) = collection.royaltyInfo(1, 1 ether);
        console2.log("ERC2981 receiver:", currentReceiver);
        
        if (collection.royaltySplitter() == OLD_SPLITTER && currentReceiver == OLD_SPLITTER) {
            console2.log("");
            console2.log("Already using OLD splitter. No action needed.");
            return;
        }
        
        console2.log("");
        console2.log("=== Reverting to OLD Splitter ===");
        console2.log("OLD_SPLITTER:", OLD_SPLITTER);
        console2.log("TOTAL_ROYALTY_BP:", TOTAL_ROYALTY_BP);
        
        uint256 deployerPk = vm.envUint("PROD_DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        
        // 1. Update royaltySplitter() - where registerSale() is called
        collection.setRoyaltySplitter(OLD_SPLITTER);
        console2.log("1. setRoyaltySplitter(OLD_SPLITTER) - DONE");
        
        // 2. Update ERC2981 royalty receiver
        collection.setDefaultRoyalty(OLD_SPLITTER, TOTAL_ROYALTY_BP);
        console2.log("2. setDefaultRoyalty(OLD_SPLITTER, 1000) - DONE");
        
        vm.stopBroadcast();
        
        // Verify
        console2.log("");
        console2.log("=== Verification ===");
        console2.log("royaltySplitter():", collection.royaltySplitter());
        (address newReceiver,) = collection.royaltyInfo(1, 1 ether);
        console2.log("ERC2981 receiver:", newReceiver);
        
        require(collection.royaltySplitter() == OLD_SPLITTER, "setRoyaltySplitter failed");
        require(newReceiver == OLD_SPLITTER, "setDefaultRoyalty failed");
        
        console2.log("");
        console2.log("SUCCESS: Reverted to OLD splitter.");
        console2.log("Existing OpenSea orders should now work correctly.");
    }
}
