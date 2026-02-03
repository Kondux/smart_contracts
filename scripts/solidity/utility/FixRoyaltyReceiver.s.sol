// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IKonduxImplementation {
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
    function royaltySplitter() external view returns (address);
    function manufacturerCutBP() external view returns (uint96);
    function partnerCutBP() external view returns (uint96);
    function creatorCutBP() external view returns (uint96);
}

/**
 * @title FixRoyaltyReceiver
 * @notice Updates ERC2981 royalty receiver to point to the correct splitter
 * @dev Run with: forge script scripts/solidity/utility/FixRoyaltyReceiver.s.sol --rpc-url mainnet --broadcast
 */
contract FixRoyaltyReceiverScript is Script {
    // Kondux Omniforge mainnet
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;
    address constant NEW_SPLITTER = 0x29272821e851b46614bA174481Fe8cFE658Bfd7A;
    
    function run() external {
        IKonduxImplementation collection = IKonduxImplementation(COLLECTION);
        
        // Check current state
        console2.log("=== Current State ===");
        (address currentReceiver, uint256 royaltyAmount) = collection.royaltyInfo(1, 1 ether);
        console2.log("Current royalty receiver:", currentReceiver);
        console2.log("Royalty amount (per 1 ETH):", royaltyAmount);
        console2.log("Collection's royaltySplitter():", collection.royaltySplitter());
        
        // Calculate total royalty BP
        uint96 mfgBP = collection.manufacturerCutBP();
        uint96 partnerBP = collection.partnerCutBP();
        uint96 creatorBP = collection.creatorCutBP();
        uint96 totalBP = mfgBP + partnerBP + creatorBP;
        
        console2.log("");
        console2.log("=== Royalty Cuts ===");
        console2.log("manufacturerCutBP:", mfgBP);
        console2.log("partnerCutBP:", partnerBP);
        console2.log("creatorCutBP:", creatorBP);
        console2.log("totalBP:", totalBP);
        
        if (currentReceiver == NEW_SPLITTER) {
            console2.log("");
            console2.log("Royalty receiver already correct. No action needed.");
            return;
        }
        
        console2.log("");
        console2.log("=== Updating Royalty Receiver ===");
        console2.log("New receiver:", NEW_SPLITTER);
        console2.log("Fee numerator (BP):", totalBP);
        
        uint256 deployerPk = vm.envUint("PROD_DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        
        collection.setDefaultRoyalty(NEW_SPLITTER, totalBP);
        
        vm.stopBroadcast();
        
        // Verify
        (address newReceiver,) = collection.royaltyInfo(1, 1 ether);
        console2.log("");
        console2.log("=== Verification ===");
        console2.log("New royalty receiver:", newReceiver);
        require(newReceiver == NEW_SPLITTER, "Update failed!");
        console2.log("SUCCESS: Royalty receiver updated.");
    }
}
