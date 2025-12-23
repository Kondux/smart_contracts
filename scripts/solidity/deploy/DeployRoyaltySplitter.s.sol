// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxRoyaltySplitter} from "contracts/KonduxRoyaltySplitter.sol";

interface IKonduxImplementation {
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256);
    function royaltySplitter() external view returns (address);
    function setRoyaltySplitter(address splitter) external;
    function manufacturerCutBP() external view returns (uint96);
    function partnerCutBP() external view returns (uint96);
    function creatorCutBP() external view returns (uint96);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

/**
 * @title DeployRoyaltySplitter
 * @notice Deploys KonduxRoyaltySplitter and configures it for the NFT collection
 * @dev Run: .\forge.ps1 script script/DeployRoyaltySplitter.s.sol:DeployRoyaltySplitterScript --rpc-url mainnet --broadcast --verify
 */
contract DeployRoyaltySplitterScript is Script {
    // NFT Collection
    address constant NFT = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;

    // Manufacturer (Kondux treasury)
    address constant MANUFACTURER_WALLET = 0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114;

    // Partner wallet
    address constant PARTNER_WALLET = 0x4936167DAE4160E5556D9294F2C78675659a3B63;

    // Admin (deployer)
    address constant ADMIN = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;

    // Default creator wallet (fallback when no creator registered for a token)
    address constant DEFAULT_CREATOR_WALLET = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;

    // Cuts in basis points (relative to MAX_TOTAL_ROYALTY_BP = 1000 = 10%)
    // These represent % of the royalty amount:
    // - 400/1000 = 40% to manufacturer
    // - 300/1000 = 30% to partner
    // - 300/1000 = 30% to creator
    uint96 constant MANUFACTURER_CUT_BP = 400;
    uint96 constant PARTNER_CUT_BP = 300;
    uint96 constant DEFAULT_CREATOR_CUT_BP = 300;

    // Current royalty: 5% = 500 BP
    uint96 constant ROYALTY_BP = 500;

    function run() external {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== KonduxRoyaltySplitter Deployment ===");
        console2.log("");
        console2.log("Deployer:", deployer);
        console2.log("NFT Collection:", NFT);
        console2.log("");

        // Check current state
        IKonduxImplementation nft = IKonduxImplementation(NFT);
        (address currentReceiver, uint256 currentRoyalty) = nft.royaltyInfo(0, 10000);

        console2.log("Current royalty receiver:", currentReceiver);
        console2.log("Current royalty BP:", currentRoyalty);
        console2.log("");

        console2.log("Splitter Configuration:");
        console2.log("  Manufacturer:", MANUFACTURER_WALLET);
        console2.log("    Cut:", MANUFACTURER_CUT_BP, "BP (40%)");
        console2.log("  Partner:", PARTNER_WALLET);
        console2.log("    Cut:", PARTNER_CUT_BP, "BP (30%)");
        console2.log("  Default Creator Cut:", DEFAULT_CREATOR_CUT_BP, "BP (30%)");
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Deploy the splitter
        console2.log("Deploying KonduxRoyaltySplitter...");
        KonduxRoyaltySplitter splitter = new KonduxRoyaltySplitter(
            NFT,                      // collection
            MANUFACTURER_WALLET,      // manufacturer wallet
            PARTNER_WALLET,           // partner wallet
            MANUFACTURER_CUT_BP,      // manufacturer cut (400 = 40%)
            PARTNER_CUT_BP,           // partner cut (300 = 30%)
            DEFAULT_CREATOR_CUT_BP,   // default creator cut (300 = 30%)
            DEFAULT_CREATOR_WALLET,   // default creator wallet (fallback)
            ADMIN                     // admin
        );

        address splitterAddr = address(splitter);
        console2.log("Splitter deployed at:", splitterAddr);
        console2.log("");

        // Set the splitter as royalty receiver on the NFT contract
        // NOTE: We use setDefaultRoyalty instead of setRoyaltySplitter because
        // setRoyaltySplitter would set royalty to manufacturerCutBP + partnerCutBP + creatorCutBP = 10000 BP = 100%
        // We want to keep 5% (500 BP) royalty and just change the receiver to the splitter
        console2.log("Setting splitter as royalty receiver on NFT contract...");
        nft.setDefaultRoyalty(splitterAddr, ROYALTY_BP);
        console2.log("Royalty receiver updated!");
        console2.log("");

        vm.stopBroadcast();

        // Verify
        (address newReceiver, uint256 newRoyalty) = nft.royaltyInfo(0, 10000);
        console2.log("=== Verification ===");
        console2.log("New royalty receiver:", newReceiver);
        console2.log("Royalty BP:", newRoyalty);
        console2.log("Receiver matches splitter:", newReceiver == splitterAddr);
        console2.log("");

        console2.log("=== Splitter Settings ===");
        console2.log("Collection:", splitter.collection());
        console2.log("Manufacturer:", splitter.manufacturerWallet());
        console2.log("Partner:", splitter.partnerWallet());
        console2.log("Manufacturer Cut BP:", splitter.manufacturerCutBP());
        console2.log("Partner Cut BP:", splitter.partnerCutBP());
        console2.log("Default Creator Cut BP:", splitter.defaultCreatorCutBP());
        console2.log("Push Mode Enabled:", splitter.pushModeEnabled());
    }
}

/**
 * @title RegisterCreators
 * @notice Registers creators for existing tokens
 * @dev Run after deployment to set up creator info for existing tokens
 */
contract RegisterCreatorsScript is Script {
    address constant NFT = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;
    address constant DEFAULT_CREATOR = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    uint96 constant CREATOR_CUT_BP = 300; // 30% of royalty

    function run() external {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");

        // Get splitter address from NFT contract
        IKonduxImplementation nft = IKonduxImplementation(NFT);
        (address splitterAddr,) = nft.royaltyInfo(0, 10000);

        console2.log("=== Register Creators ===");
        console2.log("Splitter:", splitterAddr);
        console2.log("Default Creator:", DEFAULT_CREATOR);
        console2.log("");

        KonduxRoyaltySplitter splitter = KonduxRoyaltySplitter(payable(splitterAddr));

        vm.startBroadcast(deployerKey);

        // Register creators for tokens 0-7 (current total supply is 8)
        uint256[] memory tokenIds = new uint256[](8);
        address[] memory creators = new address[](8);
        uint96[] memory cuts = new uint96[](8);

        for (uint256 i = 0; i < 8; i++) {
            tokenIds[i] = i;
            creators[i] = DEFAULT_CREATOR;
            cuts[i] = CREATOR_CUT_BP;
        }

        console2.log("Registering creators for tokens 0-7...");
        splitter.registerCreatorsBatch(tokenIds, creators, cuts);
        console2.log("Creators registered!");

        vm.stopBroadcast();

        // Verify
        for (uint256 i = 0; i < 8; i++) {
            (address creator, uint96 cut) = splitter.getCreatorInfo(i);
            console2.log("Token", i);
            console2.log("  Creator:", creator);
            console2.log("  Cut:", cut);
        }
    }
}
