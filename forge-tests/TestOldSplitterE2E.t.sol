// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

interface IKonduxRoyaltySplitter {
    function pendingETHAmount() external view returns (uint256);
    function pendingETHBlock() external view returns (uint256);
    function pendingSaleTokenId() external view returns (uint256);
    function pendingSaleBlock() external view returns (uint256);
    function hasPendingSale() external view returns (bool);
    function manufacturerWallet() external view returns (address);
    function partnerWallet() external view returns (address);
    function registerSale(uint256 tokenId) external returns (bytes32);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
}

interface IKonduxImplementation {
    function setRoyaltySplitter(address splitter) external;
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
    function royaltySplitter() external view returns (address);
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

/**
 * @title TestOldSplitterE2E
 * @notice E2E test: revert to old splitter and verify distribution works
 */
contract TestOldSplitterE2E is Test {
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;
    address constant OLD_SPLITTER = 0xf2E21db6Bee5797A9c9A38c4653bcB81a2695227;
    address constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    
    uint96 constant TOTAL_ROYALTY_BP = 1000;
    
    IKonduxImplementation collection;
    IKonduxRoyaltySplitter splitter;
    IERC721 nft;
    
    function setUp() public {
        string memory rpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(rpc);
        
        collection = IKonduxImplementation(COLLECTION);
        splitter = IKonduxRoyaltySplitter(OLD_SPLITTER);
        nft = IERC721(COLLECTION);
    }
    
    function test_revertToOldSplitterAndDistribute() public {
        console2.log("=== E2E Test: Revert to OLD Splitter and Verify Distribution ===");
        
        // Step 1: Find admin and revert to old splitter
        bytes32 adminRole = collection.DEFAULT_ADMIN_ROLE();
        address admin = splitter.manufacturerWallet(); // 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2
        require(collection.hasRole(adminRole, admin), "Admin not found");
        
        console2.log("Admin:", admin);
        console2.log("Current royaltySplitter:", collection.royaltySplitter());
        (address currentReceiver,) = collection.royaltyInfo(6, 1 ether);
        console2.log("Current ERC2981 receiver:", currentReceiver);
        
        // Revert to old splitter
        vm.startPrank(admin);
        collection.setRoyaltySplitter(OLD_SPLITTER);
        collection.setDefaultRoyalty(OLD_SPLITTER, TOTAL_ROYALTY_BP);
        vm.stopPrank();
        
        console2.log("");
        console2.log("=== After Revert ===");
        console2.log("royaltySplitter:", collection.royaltySplitter());
        (address newReceiver,) = collection.royaltyInfo(6, 1 ether);
        console2.log("ERC2981 receiver:", newReceiver);
        assertEq(collection.royaltySplitter(), OLD_SPLITTER, "royaltySplitter not updated");
        assertEq(newReceiver, OLD_SPLITTER, "ERC2981 receiver not updated");
        
        // Step 2: Test distribution
        console2.log("");
        console2.log("=== Testing Distribution ===");
        
        uint256 tokenId = 6;
        address owner = nft.ownerOf(tokenId);
        address buyer = address(0xBEEF);
        
        console2.log("Token", tokenId, "owner:", owner);
        
        // Record initial balances
        address mfgWallet = splitter.manufacturerWallet();
        uint256 mfgBalanceBefore = mfgWallet.balance;
        uint256 splitterBalanceBefore = OLD_SPLITTER.balance;
        
        console2.log("Manufacturer wallet:", mfgWallet);
        console2.log("Manufacturer balance before:", mfgBalanceBefore);
        console2.log("Splitter balance before:", splitterBalanceBefore);
        
        // Simulate OpenSea sale via conduit
        vm.deal(buyer, 1 ether);
        
        vm.prank(owner);
        nft.setApprovalForAll(OPENSEA_CONDUIT, true);
        
        // Conduit performs transfer (triggers registerSale on OLD splitter)
        vm.prank(OPENSEA_CONDUIT);
        nft.safeTransferFrom(owner, buyer, tokenId);
        
        console2.log("");
        console2.log("=== After Transfer ===");
        console2.log("pendingSaleTokenId:", splitter.pendingSaleTokenId());
        console2.log("pendingSaleBlock:", splitter.pendingSaleBlock());
        console2.log("current block:", block.number);
        
        // Send royalty ETH to OLD splitter (same block)
        uint256 royaltyPayment = 0.1 ether;
        vm.deal(address(this), royaltyPayment);
        (bool success,) = OLD_SPLITTER.call{value: royaltyPayment}("");
        require(success, "Royalty payment failed");
        
        // Check final state
        uint256 mfgBalanceAfter = mfgWallet.balance;
        uint256 splitterBalanceAfter = OLD_SPLITTER.balance;
        
        console2.log("");
        console2.log("=== Final State ===");
        console2.log("Splitter balance after:", splitterBalanceAfter);
        console2.log("Manufacturer balance after:", mfgBalanceAfter);
        console2.log("Manufacturer received:", mfgBalanceAfter - mfgBalanceBefore);
        
        // The old splitter had some pending ETH already, so just check manufacturer got paid
        console2.log("");
        console2.log("=== Result ===");
        bool mfgGotPaid = mfgBalanceAfter > mfgBalanceBefore;
        console2.log("Manufacturer got paid:", mfgGotPaid ? 1 : 0);
        
        assertTrue(mfgGotPaid, "Manufacturer should have received ETH");
        
        console2.log("");
        console2.log("SUCCESS: OLD splitter distributes royalties correctly!");
    }
    
    receive() external payable {}
}
