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
    function lastSoldTokenId() external view returns (uint256);
    function pushModeEnabled() external view returns (bool);
    function collection() external view returns (address);
    function manufacturerWallet() external view returns (address);
    function partnerWallet() external view returns (address);
    function manufacturerCutBP() external view returns (uint96);
    function partnerCutBP() external view returns (uint96);
    function registerSale(uint256 tokenId) external returns (bytes32);
    function sweepETH(uint256 tokenId) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function COLLECTION_ROLE() external view returns (bytes32);
    function ADMIN_ROLE() external view returns (bytes32);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function setApprovalForAll(address operator, bool approved) external;
}

interface IKonduxImplementation {
    function royaltySplitter() external view returns (address);
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function addAccountsToAuthorizers(address[] calldata accounts) external;
}

/**
 * @title SplitterSameBlockDebug
 * @notice Debug test for royalty splitter same-block matching on mainnet fork
 * @dev Tests the actual Kondux Omniforge splitter behavior
 */
contract SplitterSameBlockDebug is Test {
    // Mainnet addresses
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;
    address constant SPLITTER = 0x29272821e851b46614bA174481Fe8cFE658Bfd7A;
    
    IKonduxRoyaltySplitter splitter;
    IERC721 nft;
    
    function setUp() public {
        // Fork mainnet
        string memory rpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(rpc);
        
        splitter = IKonduxRoyaltySplitter(SPLITTER);
        nft = IERC721(COLLECTION);
    }
    
    function test_inspectSplitterState() public view {
        console2.log("=== Splitter State ===");
        console2.log("collection:", splitter.collection());
        console2.log("pushModeEnabled:", splitter.pushModeEnabled() ? 1 : 0);
        console2.log("manufacturerWallet:", splitter.manufacturerWallet());
        console2.log("partnerWallet:", splitter.partnerWallet());
        console2.log("manufacturerCutBP:", splitter.manufacturerCutBP());
        console2.log("partnerCutBP:", splitter.partnerCutBP());
        console2.log("");
        console2.log("=== Pending State ===");
        console2.log("pendingETHAmount:", splitter.pendingETHAmount());
        console2.log("pendingETHBlock:", splitter.pendingETHBlock());
        console2.log("pendingSaleTokenId:", splitter.pendingSaleTokenId());
        console2.log("pendingSaleBlock:", splitter.pendingSaleBlock());
        console2.log("hasPendingSale:", splitter.hasPendingSale() ? 1 : 0);
        console2.log("lastSoldTokenId:", splitter.lastSoldTokenId());
        console2.log("");
        console2.log("=== Splitter Balance ===");
        console2.log("ETH balance:", SPLITTER.balance);
        console2.log("current block:", block.number);
        
        console2.log("");
        console2.log("=== ERC2981 Royalty Info (token 6, 1 ETH sale) ===");
        IKonduxImplementation impl = IKonduxImplementation(COLLECTION);
        (address receiver, uint256 royaltyAmount) = impl.royaltyInfo(6, 1 ether);
        console2.log("royaltyReceiver:", receiver);
        console2.log("royaltyAmount:", royaltyAmount);
        console2.log("receiver == SPLITTER:", receiver == SPLITTER ? 1 : 0);
    }
    
    function test_sameBlockMatching_saleFirst() public {
        console2.log("=== Test: Sale registered BEFORE ETH arrives (same block) ===");
        
        // Get token 6 owner
        uint256 tokenId = 6;
        address owner = nft.ownerOf(tokenId);
        console2.log("Token", tokenId, "owner:", owner);
        
        // Check if collection has COLLECTION_ROLE on splitter
        bytes32 collectionRole = splitter.COLLECTION_ROLE();
        bool hasRole = splitter.hasRole(collectionRole, COLLECTION);
        console2.log("Collection has COLLECTION_ROLE:", hasRole ? 1 : 0);
        
        // Record initial state
        uint256 splitterBalanceBefore = SPLITTER.balance;
        uint256 mfgWallet = uint160(splitter.manufacturerWallet());
        uint256 partnerWallet = uint160(splitter.partnerWallet());
        uint256 mfgBalanceBefore = address(uint160(mfgWallet)).balance;
        uint256 partnerBalanceBefore = address(uint160(partnerWallet)).balance;
        
        console2.log("");
        console2.log("=== Before Transfer ===");
        console2.log("Splitter balance:", splitterBalanceBefore);
        console2.log("Manufacturer balance:", mfgBalanceBefore);
        console2.log("Partner balance:", partnerBalanceBefore);
        
        // Simulate a transfer (this triggers registerSale in _beforeTokenTransfer)
        address buyer = address(0xBEEF);
        vm.deal(buyer, 1 ether);
        
        // Approve and transfer
        vm.prank(owner);
        nft.setApprovalForAll(buyer, true);
        
        vm.prank(buyer);
        nft.safeTransferFrom(owner, buyer, tokenId);
        
        // Check pending state after transfer
        console2.log("");
        console2.log("=== After Transfer (before ETH) ===");
        console2.log("pendingSaleTokenId:", splitter.pendingSaleTokenId());
        console2.log("pendingSaleBlock:", splitter.pendingSaleBlock());
        console2.log("hasPendingSale:", splitter.hasPendingSale() ? 1 : 0);
        console2.log("current block:", block.number);
        
        // Now send ETH to splitter (simulating royalty payment)
        uint256 royaltyAmount = 0.01 ether;
        vm.deal(address(this), royaltyAmount);
        (bool success,) = SPLITTER.call{value: royaltyAmount}("");
        require(success, "ETH transfer failed");
        
        // Check state after ETH
        console2.log("");
        console2.log("=== After ETH Sent ===");
        console2.log("Splitter balance:", SPLITTER.balance);
        console2.log("pendingETHAmount:", splitter.pendingETHAmount());
        console2.log("pendingETHBlock:", splitter.pendingETHBlock());
        console2.log("pendingSaleTokenId:", splitter.pendingSaleTokenId());
        console2.log("Manufacturer balance:", address(uint160(mfgWallet)).balance);
        console2.log("Partner balance:", address(uint160(partnerWallet)).balance);
        
        // Check if distribution happened
        bool distributed = SPLITTER.balance == splitterBalanceBefore; // Should be same if distributed
        console2.log("");
        console2.log("=== Result ===");
        console2.log("ETH distributed immediately:", distributed ? 1 : 0);
        console2.log("ETH stuck in splitter:", SPLITTER.balance - splitterBalanceBefore);
    }
    
    function test_sameBlockMatching_ethFirst() public {
        console2.log("=== Test: ETH arrives BEFORE sale registered (same block) ===");
        
        uint256 tokenId = 6;
        address owner = nft.ownerOf(tokenId);
        
        // Record initial state
        uint256 splitterBalanceBefore = SPLITTER.balance;
        
        console2.log("=== Before Anything ===");
        console2.log("Splitter balance:", splitterBalanceBefore);
        console2.log("current block:", block.number);
        
        // Send ETH first
        uint256 royaltyAmount = 0.01 ether;
        vm.deal(address(this), royaltyAmount);
        (bool success,) = SPLITTER.call{value: royaltyAmount}("");
        require(success, "ETH transfer failed");
        
        console2.log("");
        console2.log("=== After ETH (before transfer) ===");
        console2.log("Splitter balance:", SPLITTER.balance);
        console2.log("pendingETHAmount:", splitter.pendingETHAmount());
        console2.log("pendingETHBlock:", splitter.pendingETHBlock());
        
        // Now do transfer (triggers registerSale)
        address buyer = address(0xBEEF);
        vm.prank(owner);
        nft.setApprovalForAll(buyer, true);
        
        vm.prank(buyer);
        nft.safeTransferFrom(owner, buyer, tokenId);
        
        console2.log("");
        console2.log("=== After Transfer ===");
        console2.log("Splitter balance:", SPLITTER.balance);
        console2.log("pendingETHAmount:", splitter.pendingETHAmount());
        console2.log("pendingSaleTokenId:", splitter.pendingSaleTokenId());
        
        bool distributed = SPLITTER.balance == splitterBalanceBefore;
        console2.log("");
        console2.log("=== Result ===");
        console2.log("ETH distributed immediately:", distributed ? 1 : 0);
        console2.log("ETH stuck in splitter:", SPLITTER.balance - splitterBalanceBefore);
    }
    
    function test_differentBlockMatching() public {
        console2.log("=== Test: ETH arrives in DIFFERENT block than sale ===");
        
        uint256 tokenId = 6;
        address owner = nft.ownerOf(tokenId);
        
        uint256 splitterBalanceBefore = SPLITTER.balance;
        
        // Do transfer first
        address buyer = address(0xBEEF);
        vm.prank(owner);
        nft.setApprovalForAll(buyer, true);
        
        vm.prank(buyer);
        nft.safeTransferFrom(owner, buyer, tokenId);
        
        console2.log("=== After Transfer (block", block.number, ") ===");
        console2.log("pendingSaleTokenId:", splitter.pendingSaleTokenId());
        console2.log("pendingSaleBlock:", splitter.pendingSaleBlock());
        
        // Roll to next block
        vm.roll(block.number + 1);
        
        // Now send ETH
        uint256 royaltyAmount = 0.01 ether;
        vm.deal(address(this), royaltyAmount);
        (bool success,) = SPLITTER.call{value: royaltyAmount}("");
        require(success, "ETH transfer failed");
        
        console2.log("");
        console2.log("=== After ETH (block", block.number, ") ===");
        console2.log("Splitter balance:", SPLITTER.balance);
        console2.log("pendingETHAmount:", splitter.pendingETHAmount());
        console2.log("pendingETHBlock:", splitter.pendingETHBlock());
        
        bool distributed = SPLITTER.balance == splitterBalanceBefore;
        console2.log("");
        console2.log("=== Result ===");
        console2.log("ETH distributed immediately:", distributed ? 1 : 0);
        console2.log("ETH stuck in splitter:", SPLITTER.balance - splitterBalanceBefore);
    }
    
    receive() external payable {}
    
    /**
     * @notice E2E test: Fix royalty receiver and verify distribution works
     * @dev This simulates what happens after we run FixRoyaltyReceiver.s.sol on mainnet
     */
    function test_e2e_fixRoyaltyAndDistribute() public {
        console2.log("=== E2E Test: Fix Royalty Receiver and Verify Distribution ===");
        
        IKonduxImplementation impl = IKonduxImplementation(COLLECTION);
        
        // Step 1: Check current royalty receiver (should be old splitter)
        (address oldReceiver, uint256 royaltyAmount) = impl.royaltyInfo(6, 1 ether);
        console2.log("Current royalty receiver:", oldReceiver);
        console2.log("Royalty amount (10% of 1 ETH):", royaltyAmount);
        console2.log("Expected splitter:", SPLITTER);
        console2.log("Receiver is correct:", oldReceiver == SPLITTER ? 1 : 0);
        
        // Step 2: Fix the royalty receiver (impersonate admin)
        bytes32 adminRole = impl.DEFAULT_ADMIN_ROLE();
        // Find an admin - the deployer should be admin
        address admin = 0x74C6192D6d9Ef8440323dBE5E3a85fc6830F4dc7; // Known deployer
        
        // Check if this is an admin
        bool isAdmin = impl.hasRole(adminRole, admin);
        console2.log("");
        console2.log("Admin address:", admin);
        console2.log("Has admin role:", isAdmin ? 1 : 0);
        
        if (!isAdmin) {
            // Try to find admin from splitter
            admin = splitter.manufacturerWallet();
            isAdmin = impl.hasRole(adminRole, admin);
            console2.log("Trying manufacturer wallet:", admin);
            console2.log("Has admin role:", isAdmin ? 1 : 0);
        }
        
        require(isAdmin, "Could not find admin");
        
        // Calculate total royalty BP (should be 1000 = 10%)
        uint96 totalBP = 1000; // 10% total royalty
        
        console2.log("");
        console2.log("=== Fixing Royalty Receiver ===");
        vm.prank(admin);
        impl.setDefaultRoyalty(SPLITTER, totalBP);
        
        // Verify fix
        (address newReceiver,) = impl.royaltyInfo(6, 1 ether);
        console2.log("New royalty receiver:", newReceiver);
        console2.log("Receiver is now correct:", newReceiver == SPLITTER ? 1 : 0);
        require(newReceiver == SPLITTER, "Royalty receiver not updated!");
        
        // Step 3: Test distribution with same-block matching
        console2.log("");
        console2.log("=== Testing Distribution ===");
        
        uint256 tokenId = 6;
        address owner = nft.ownerOf(tokenId);
        console2.log("Token", tokenId, "owner:", owner);
        
        // Use OpenSea conduit as operator (already whitelisted)
        address buyer = address(0xBEEF);
        address OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
        console2.log("Using OpenSea conduit as operator:", OPENSEA_CONDUIT);
        
        // Record initial balances
        address mfgWallet = splitter.manufacturerWallet();
        address partnerAddr = splitter.partnerWallet();
        uint256 mfgBalanceBefore = mfgWallet.balance;
        uint256 partnerBalanceBefore = partnerAddr.balance;
        uint256 splitterBalanceBefore = SPLITTER.balance;
        
        console2.log("Manufacturer wallet:", mfgWallet);
        console2.log("Partner wallet:", partnerAddr);
        console2.log("Manufacturer balance before:", mfgBalanceBefore);
        console2.log("Partner balance before:", partnerBalanceBefore);
        console2.log("Splitter balance before:", splitterBalanceBefore);
        
        // Simulate sale: transfer triggers registerSale
        // Owner approves conduit, conduit transfers to buyer
        vm.deal(buyer, 1 ether);
        
        vm.prank(owner);
        nft.setApprovalForAll(OPENSEA_CONDUIT, true);
        
        // Conduit performs the transfer (simulating Seaport fulfillment)
        vm.prank(OPENSEA_CONDUIT);
        nft.safeTransferFrom(owner, buyer, tokenId);
        
        console2.log("");
        console2.log("=== After Transfer (sale registered) ===");
        console2.log("pendingSaleTokenId:", splitter.pendingSaleTokenId());
        console2.log("pendingSaleBlock:", splitter.pendingSaleBlock());
        console2.log("current block:", block.number);
        
        // Send royalty ETH (same block - this is what Seaport does)
        uint256 royaltyPayment = 0.1 ether; // 10% of 1 ETH sale
        vm.deal(address(this), royaltyPayment);
        (bool success,) = SPLITTER.call{value: royaltyPayment}("");
        require(success, "Royalty payment failed");
        
        // Check final state
        uint256 mfgBalanceAfter = mfgWallet.balance;
        uint256 partnerBalanceAfter = partnerAddr.balance;
        uint256 splitterBalanceAfter = SPLITTER.balance;
        
        console2.log("");
        console2.log("=== Final State ===");
        console2.log("Splitter balance after:", splitterBalanceAfter);
        console2.log("Manufacturer balance after:", mfgBalanceAfter);
        console2.log("Partner balance after:", partnerBalanceAfter);
        console2.log("Manufacturer received:", mfgBalanceAfter - mfgBalanceBefore);
        console2.log("Partner received:", partnerBalanceAfter - partnerBalanceBefore);
        
        // Verify distribution happened
        bool distributed = splitterBalanceAfter == splitterBalanceBefore;
        console2.log("");
        console2.log("=== Result ===");
        console2.log("ETH distributed immediately:", distributed ? 1 : 0);
        console2.log("ETH stuck in splitter:", splitterBalanceAfter - splitterBalanceBefore);
        
        // Assert success
        assertEq(splitterBalanceAfter, splitterBalanceBefore, "ETH should not remain in splitter");
        assertTrue(mfgBalanceAfter > mfgBalanceBefore, "Manufacturer should have received ETH");
        
        console2.log("");
        console2.log("SUCCESS: Royalty distribution working correctly!");
    }
}
