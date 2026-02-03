// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IKonduxImplementation {
    function setRoyaltySplitter(address splitter) external;
    function royaltySplitter() external view returns (address);
}

/**
 * @title SetRoyaltySplitterOnly
 * @notice Sets royaltySplitter to OLD splitter
 */
contract SetRoyaltySplitterOnlyScript is Script {
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;
    address constant OLD_SPLITTER = 0xf2E21db6Bee5797A9c9A38c4653bcB81a2695227;
    
    function run() external {
        IKonduxImplementation collection = IKonduxImplementation(COLLECTION);
        
        console2.log("Current royaltySplitter:", collection.royaltySplitter());
        console2.log("Setting to:", OLD_SPLITTER);
        
        uint256 deployerPk = vm.envUint("PROD_DEPLOYER_PK");
        vm.startBroadcast(deployerPk);
        
        collection.setRoyaltySplitter(OLD_SPLITTER);
        
        vm.stopBroadcast();
        
        console2.log("New royaltySplitter:", collection.royaltySplitter());
        require(collection.royaltySplitter() == OLD_SPLITTER, "Failed!");
        console2.log("SUCCESS!");
    }
}
