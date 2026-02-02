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
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function owner() external view returns (address);
}

/**
 * @title DeploySplitterOmniforge
 * @notice Deploys a fresh KonduxRoyaltySplitter for the Kondux Omniforge (CRTR)
 *         collection and updates the collection's ERC-2981 royalty receiver.
 *
 * @dev The old splitter (0xf2E21db6...5227) is non-functional — missing
 *      distributeETH/ERC20 and AccessControl. This script deploys the current
 *      KonduxRoyaltySplitter and links it.
 *
 * Usage:
 *   # Dry-run:
 *   forge script scripts/solidity/deploy/DeploySplitterOmniforge.s.sol -vvv --rpc-url mainnet
 *
 *   # Broadcast + verify:
 *   forge script scripts/solidity/deploy/DeploySplitterOmniforge.s.sol --rpc-url mainnet --broadcast --verify -vvv
 *
 *   # Local fork:
 *   forge script scripts/solidity/deploy/DeploySplitterOmniforge.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv
 */
contract DeploySplitterOmniforgeScript is Script {
    // ─── Collection ──────────────────────────────────────────────────────
    address constant COLLECTION = 0xc410f83c9b444d72799f83A45A4b5b2fe979e2EE;

    // ─── Wallets ─────────────────────────────────────────────────────────
    // All royalties go to the owner for this collection
    address constant ADMIN = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    address constant MANUFACTURER_WALLET = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    address constant PARTNER_WALLET = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;
    address constant DEFAULT_CREATOR_WALLET = 0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2;

    // ─── Cuts (relative to royalty received, in BP) ──────────────────────
    // These determine how incoming royalty ETH/ERC20 is split inside the splitter.
    // The collection's ERC-2981 royalty is 1000 BP (10% of sale price).
    // Splitter splits: 500/1000 (50%) to manufacturer, 0 to partner, 500/1000 (50%) to creator.
    uint96 constant MANUFACTURER_CUT_BP = 500;
    uint96 constant PARTNER_CUT_BP = 0;
    uint96 constant DEFAULT_CREATOR_CUT_BP = 500;

    // ERC-2981 on-chain royalty in basis points (10% of sale price)
    uint96 constant ROYALTY_BP = 1000;

    function run() external {
        uint256 deployerKey;
        if (block.chainid == 1) {
            deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        } else if (block.chainid == 31337) {
            string memory pk = vm.envOr("PROD_DEPLOYER_PK", string(""));
            deployerKey = bytes(pk).length > 0
                ? vm.envUint("PROD_DEPLOYER_PK")
                : 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        } else {
            deployerKey = vm.envUint("DEPLOYER_PK");
        }

        address deployer = vm.addr(deployerKey);
        IKonduxImplementation nft = IKonduxImplementation(COLLECTION);

        // ── Pre-flight ──────────────────────────────────────────────────
        console2.log("=== Deploy Splitter: Kondux Omniforge (CRTR) ===");
        console2.log("Collection:", COLLECTION);
        console2.log("  Name:", nft.name());
        console2.log("  Symbol:", nft.symbol());
        console2.log("  Owner:", nft.owner());
        console2.log("Deployer:", deployer);
        console2.log("");

        // Verify deployer is admin
        bytes32 adminRole = nft.DEFAULT_ADMIN_ROLE();
        bool isAdmin = nft.hasRole(adminRole, deployer);
        console2.log("Deployer is admin:", isAdmin);
        require(isAdmin, "Deployer must have DEFAULT_ADMIN_ROLE on collection");

        // Show current royalty state
        (address currentReceiver, uint256 currentBP) = nft.royaltyInfo(0, 10000);
        address currentSplitter = nft.royaltySplitter();
        console2.log("");
        console2.log("Current state:");
        console2.log("  ERC-2981 receiver:", currentReceiver);
        console2.log("  ERC-2981 royalty BP:", currentBP);
        console2.log("  royaltySplitter():", currentSplitter);
        console2.log("");

        console2.log("New splitter config:");
        console2.log("  Manufacturer:", MANUFACTURER_WALLET);
        console2.log("  Partner:", PARTNER_WALLET);
        console2.log("  Creator:", DEFAULT_CREATOR_WALLET);
        console2.log("  Mfg cut: %d BP, Partner cut: %d BP", uint256(MANUFACTURER_CUT_BP), uint256(PARTNER_CUT_BP));
        console2.log("  Creator cut: %d BP", uint256(DEFAULT_CREATOR_CUT_BP));
        console2.log("  On-chain royalty: %d BP", uint256(ROYALTY_BP));
        console2.log("");

        // ── Deploy ──────────────────────────────────────────────────────
        vm.startBroadcast(deployerKey);

        console2.log("Deploying KonduxRoyaltySplitter...");
        KonduxRoyaltySplitter splitter = new KonduxRoyaltySplitter(
            COLLECTION,
            MANUFACTURER_WALLET,
            PARTNER_WALLET,
            MANUFACTURER_CUT_BP,
            PARTNER_CUT_BP,
            DEFAULT_CREATOR_CUT_BP,
            DEFAULT_CREATOR_WALLET,
            ADMIN
        );
        address splitterAddr = address(splitter);
        console2.log("Splitter deployed at:", splitterAddr);
        console2.log("");

        // Use setRoyaltySplitter to update BOTH the royaltySplitter storage
        // variable AND the ERC-2981 receiver in one call. This is critical:
        // setDefaultRoyalty alone only updates ERC-2981 but leaves
        // royaltySplitter() pointing to the old address, which breaks the
        // _beforeTokenTransfer hook (registerSale) and OpenSea simulations.
        //
        // setRoyaltySplitter computes totalRoyalty from the collection's stored
        // manufacturerCutBP + partnerCutBP + creatorCutBP. Verify these match
        // the intended ROYALTY_BP before proceeding.
        {
            (address _r, uint256 existingBP) = nft.royaltyInfo(0, 10000);
            uint96 storedTotal = nft.manufacturerCutBP() + nft.partnerCutBP() + nft.creatorCutBP();
            console2.log("Collection stored cuts sum:", uint256(storedTotal));
            console2.log("Intended royalty BP:", uint256(ROYALTY_BP));
            require(
                storedTotal == ROYALTY_BP,
                "ABORT: collection stored cuts != intended royalty BP. Use setDefaultRoyalty + setRoyaltySplitter manually."
            );
        }

        console2.log("Setting splitter via setRoyaltySplitter (updates storage + ERC-2981)...");
        nft.setRoyaltySplitter(splitterAddr);
        console2.log("royaltySplitter storage + ERC-2981 receiver updated");

        vm.stopBroadcast();

        // ── Verify ──────────────────────────────────────────────────────
        console2.log("");
        console2.log("=== Post-Deployment Verification ===");

        address storageSplitter = nft.royaltySplitter();
        console2.log("royaltySplitter():", storageSplitter);
        require(storageSplitter == splitterAddr, "FAIL: royaltySplitter storage mismatch");
        console2.log("  [PASS] royaltySplitter storage = new splitter");

        (address newReceiver, uint256 newBP) = nft.royaltyInfo(0, 10000);
        console2.log("ERC-2981 receiver:", newReceiver);
        console2.log("ERC-2981 royalty BP:", newBP);
        require(newReceiver == splitterAddr, "FAIL: ERC-2981 receiver mismatch");
        require(newBP == ROYALTY_BP, "FAIL: ERC-2981 royalty BP mismatch");
        console2.log("  [PASS] ERC-2981 receiver = splitter");
        console2.log("  [PASS] Royalty = %d BP", uint256(ROYALTY_BP));

        console2.log("");
        console2.log("Splitter state:");
        console2.log("  collection:", splitter.collection());
        require(splitter.collection() == COLLECTION, "FAIL: collection mismatch");
        console2.log("  [PASS] collection matches");

        console2.log("  manufacturerWallet:", splitter.manufacturerWallet());
        console2.log("  partnerWallet:", splitter.partnerWallet());
        console2.log("  defaultCreatorWallet:", splitter.defaultCreatorWallet());
        require(splitter.manufacturerWallet() == MANUFACTURER_WALLET, "FAIL: mfg wallet");
        require(splitter.partnerWallet() == PARTNER_WALLET, "FAIL: partner wallet");
        require(splitter.defaultCreatorWallet() == DEFAULT_CREATOR_WALLET, "FAIL: creator wallet");
        console2.log("  [PASS] All wallets correct");

        console2.log("  manufacturerCutBP:", splitter.manufacturerCutBP());
        console2.log("  partnerCutBP:", splitter.partnerCutBP());
        console2.log("  defaultCreatorCutBP:", splitter.defaultCreatorCutBP());
        require(splitter.manufacturerCutBP() == MANUFACTURER_CUT_BP, "FAIL: mfg cut");
        require(splitter.partnerCutBP() == PARTNER_CUT_BP, "FAIL: partner cut");
        require(splitter.defaultCreatorCutBP() == DEFAULT_CREATOR_CUT_BP, "FAIL: creator cut");
        console2.log("  [PASS] All cuts correct");

        console2.log("  pushModeEnabled:", splitter.pushModeEnabled());

        // Role checks
        bytes32 splitterAdminRole = splitter.ADMIN_ROLE();
        bytes32 feeAdminRole = splitter.FEE_ADMIN_ROLE();
        console2.log("  ADMIN has ADMIN_ROLE:", splitter.hasRole(splitterAdminRole, ADMIN));
        console2.log("  ADMIN has FEE_ADMIN:", splitter.hasRole(feeAdminRole, ADMIN));
        require(splitter.hasRole(splitterAdminRole, ADMIN), "FAIL: admin missing ADMIN_ROLE");
        console2.log("  [PASS] Roles configured");

        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("Splitter:", splitterAddr);
        console2.log("Verify on Etherscan:");
        console2.log("  Constructor args: collection, mfgWallet, partnerWallet,");
        console2.log("    mfgCutBP, partnerCutBP, creatorCutBP, creatorWallet, admin");
    }
}
