// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

interface IERC721 {
    function ownerOf(uint256) external view returns (address);
    function safeTransferFrom(address, address, uint256) external;
    function isApprovedForAll(address, address) external view returns (bool);
    function setApprovalForAll(address, bool) external;
    function royaltySplitter() external view returns (address);
    function royaltyInfo(uint256, uint256) external view returns (address, uint256);
    function getTransferValidator() external view returns (address);
}

interface ISplitter {
    function collection() external view returns (address);
    function manufacturerWallet() external view returns (address);
    function partnerWallet() external view returns (address);
    function creatorWallet() external view returns (address);
    function manufacturerCutBP() external view returns (uint256);
    function partnerCutBP() external view returns (uint256);
    function defaultCreatorCutBP() external view returns (uint256);
}

contract TestOmniforgeTransfer is Test {
    IERC721 nft = IERC721(0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE);
    address constant SEAPORT_16 = 0x0000000000000068F116a894984e2DB1123eB395;
    address constant SEAPORT_15 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address constant OS_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    function test_verifyOnChainState() public view {
        address splitter = nft.royaltySplitter();
        assertEq(splitter, 0x29272821e851b46614bA174481Fe8cFE658Bfd7A);

        (address receiver, uint256 amount) = nft.royaltyInfo(5, 10000);
        assertEq(receiver, splitter);
        assertEq(amount, 1000);

        ISplitter s = ISplitter(splitter);
        assertEq(s.collection(), address(nft));
        assertEq(s.manufacturerCutBP(), 500);
        assertEq(s.defaultCreatorCutBP(), 500);

        console2.log("All on-chain state verified OK");
    }

    function test_transferViaSeaport16() public {
        uint256 tokenId = 5;
        address owner = nft.ownerOf(tokenId);
        address buyer = address(0xBEEF);

        vm.prank(owner);
        nft.setApprovalForAll(SEAPORT_16, true);

        vm.prank(SEAPORT_16);
        nft.safeTransferFrom(owner, buyer, tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        console2.log("Seaport 1.6 transfer: SUCCESS");
    }

    function test_transferViaSeaport15() public {
        uint256 tokenId = 5;
        address owner = nft.ownerOf(tokenId);
        address buyer = address(0xBEEF);

        vm.prank(owner);
        nft.setApprovalForAll(SEAPORT_15, true);

        vm.prank(SEAPORT_15);
        nft.safeTransferFrom(owner, buyer, tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        console2.log("Seaport 1.5 transfer: SUCCESS");
    }

    function test_transferViaConduit() public {
        uint256 tokenId = 5;
        address owner = nft.ownerOf(tokenId);
        address buyer = address(0xBEEF);

        vm.prank(owner);
        nft.setApprovalForAll(OS_CONDUIT, true);

        vm.prank(OS_CONDUIT);
        nft.safeTransferFrom(owner, buyer, tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        console2.log("OpenSea Conduit transfer: SUCCESS");
    }

    function test_ownerDirectTransfer() public {
        uint256 tokenId = 5;
        address owner = nft.ownerOf(tokenId);
        address receiver = address(0xCAFE);

        vm.prank(owner);
        nft.safeTransferFrom(owner, receiver, tokenId);

        assertEq(nft.ownerOf(tokenId), receiver);
        console2.log("Owner direct transfer: SUCCESS");
    }
}
