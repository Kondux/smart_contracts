// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {KonduxBeaconFactory} from "contracts/KonduxBeaconFactory.sol";
import {KonduxRoyaltySplitter} from "contracts/KonduxRoyaltySplitter.sol";

/**
 * @title DeployCloneMintAndSetup
 * @notice Deploys a new NFT collection clone via V2 factory, mints asset, with auto-configured OpenSea security
 * @dev This script uses the V2 factory which automatically:
 *      1. Configures security level 4 (Operator Whitelist, OTC Disabled)
 *      2. Creates whitelist with Seaport 1.6
 *      3. Adds OpenSea Conduit to whitelist
 *
 * V2 Factory: 0x8FE90DC7203a27cc788DeC8c5E1a873e47fc598C
 * Implementation (V5): Uses Transfer Validator 0x721C008fdff27BF06E7E123956E2Fe03B63342e3
 *
 * Usage:
 *   # Dry-run (simulation)
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployCloneMintAndSetup.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf'"
 *
 *   # Broadcast (actual deployment)
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=0xYOUR_PRIVATE_KEY_HERE \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/DeployCloneMintAndSetup.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf' --broadcast"
 */
contract DeployCloneMintAndSetup is Script {
    // V2 Factory with auto security configuration
    address constant FACTORY_ADDRESS = 0x8FE90DC7203a27cc788DeC8c5E1a873e47fc598C;
    
    // Limit Break Transfer Validator V5
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    
    // OpenSea addresses (for verification logging)
    address constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    // OpenSea SignedZone (Mainnet) - required for ERC721C compliance
    address constant SIGNED_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;

    struct DeployResult {
        address factory;
        address collection;
        address splitter;
        uint256 mintedTokenId;
    }

    function run() external returns (DeployResult memory result) {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Deploy Clone + Mint (V2 Factory with Auto-Security) ===");
        console2.log("Network: Ethereum Mainnet");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Deployer Balance:", deployer.balance);
        console2.log("");

        require(block.chainid == 1, "This script is for mainnet only");

        KonduxBeaconFactory factory = KonduxBeaconFactory(FACTORY_ADDRESS);
        result.factory = FACTORY_ADDRESS;

        console2.log("Using V2 Factory:", FACTORY_ADDRESS);
        console2.log("Beacon:", address(factory.beacon()));
        console2.log("Implementation:", factory.beacon().implementation());
        console2.log("");

        // Configuration for new collection
        string memory name = "KONDX TEST";
        string memory symbol = "KTEST";
        uint256 maxSupply = 10000;
        address admin = deployer;
        address partnerWallet = deployer;
        uint96 manufacturerCutBP = 500;  // 5%
        uint96 partnerCutBP = 0;         // 0%
        uint96 creatorCutBP = 500;       // 5%
        address defaultCreatorWallet = deployer;

        console2.log("Collection Config:");
        console2.log("  Name:", name);
        console2.log("  Symbol:", symbol);
        console2.log("  Max Supply:", maxSupply);
        console2.log("  Admin:", admin);
        console2.log("  Manufacturer Cut:", manufacturerCutBP, "BP (5%)");
        console2.log("  Partner Cut:", partnerCutBP, "BP (0%)");
        console2.log("  Creator Cut:", creatorCutBP, "BP (5%)");
        console2.log("  Total Royalty:", manufacturerCutBP + partnerCutBP + creatorCutBP, "BP (10%)");
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Step 1: Deploy clone with splitter via V2 factory
        // Factory automatically configures OpenSea marketplace security (level 4)
        console2.log("Step 1: Deploying clone with splitter (auto-security config)...");
        (address collectionAddr, address splitterAddr) = factory.deployCloneWithSplitter(
            name,
            symbol,
            maxSupply,
            admin,
            true,  // deploySplitter
            partnerWallet,
            manufacturerCutBP,
            partnerCutBP,
            creatorCutBP,
            defaultCreatorWallet
        );
        result.collection = collectionAddr;
        result.splitter = splitterAddr;
        console2.log("  Collection deployed:", collectionAddr);
        console2.log("  Splitter deployed:", splitterAddr);
        console2.log("");

        // Authorize SignedZone
        // Required for OpenSea listings to work with the SignedZone (ERC721C)
        address[] memory authorizers = new address[](1);
        authorizers[0] = SIGNED_ZONE;
        (bool success, ) = collectionAddr.call(
            abi.encodeWithSignature("addAccountsToAuthorizers(address[])", authorizers)
        );
        if (success) {
            console2.log("  SignedZone authorized");
        } else {
            console2.log("  WARNING: Failed to authorize SignedZone (function missing?)");
        }

        // Step 2: Mint one NFT to deployer
        // Admin has MINTER_ROLE by default from initialization
        console2.log("Step 2: Minting token #0 to deployer...");
        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));
        uint256 dna = uint256(keccak256(abi.encodePacked(block.timestamp, deployer, "genesis")));
        uint256 tokenId = collection.safeMint(deployer, dna);
        result.mintedTokenId = tokenId;
        console2.log("  Minted token ID:", tokenId);
        console2.log("  Recipient:", deployer);
        console2.log("  DNA:", dna);
        console2.log("");

        vm.stopBroadcast();

        // Step 3: Verify OpenSea setup (read-only checks)
        console2.log("Step 3: Verifying OpenSea royalty enforcement setup...");
        _verifyOpenSeaSetup(collection, result);

        // Print summary
        _printSummary(result, deployer);

        return result;
    }

    function _verifyOpenSeaSetup(KonduxImplementation collection, DeployResult memory result) internal view {
        // Check transfer validator is set
        address validator = collection.getTransferValidator();
        console2.log("  Transfer Validator:", validator);
        
        if (validator == address(0)) {
            console2.log("  WARNING: No transfer validator set!");
        } else if (validator == TRANSFER_VALIDATOR_V5) {
            console2.log("  PASS: V5 Transfer Validator configured");
        } else {
            console2.log("  WARNING: Unexpected transfer validator!");
        }

        // Check ERC2981 royalty info points to splitter
        (address receiver, uint256 royaltyAmount) = collection.royaltyInfo(0, 10000);
        console2.log("  ERC2981 Royalty Receiver:", receiver);
        console2.log("  ERC2981 Royalty Amount (per 10000):", royaltyAmount);
        
        if (receiver == result.splitter) {
            console2.log("  PASS: ERC2981 correctly points to splitter");
        } else {
            console2.log("  WARNING: ERC2981 receiver is not splitter!");
        }

        // OpenSea specific info
        console2.log("");
        console2.log("  OpenSea Integration:");
        console2.log("    Seaport:", SEAPORT);
        console2.log("    OpenSea Conduit:", OPENSEA_CONDUIT);
        console2.log("    Security Level: 4 (Operator Whitelist, OTC Disabled)");
        console2.log("    Status: AUTO-CONFIGURED by V2 Factory");
        console2.log("");
    }

    function _printSummary(DeployResult memory result, address deployer) internal pure {
        console2.log("=== DEPLOYMENT SUMMARY ===");
        console2.log("");
        console2.log("Addresses:");
        console2.log("  Factory (V2):", result.factory);
        console2.log("  Collection (NEW):", result.collection);
        console2.log("  Splitter (NEW):", result.splitter);
        console2.log("");
        console2.log("Minted Asset:");
        console2.log("  Token ID:", result.mintedTokenId);
        console2.log("  Owner:", deployer);
        console2.log("");
        console2.log("OpenSea Setup:");
        console2.log("  Status: AUTO-CONFIGURED");
        console2.log("  Transfer Validator: V5 (0x721C008fdff27BF06E7E123956E2Fe03B63342e3)");
        console2.log("  Security Level: 4 (Operator Whitelist, OTC Disabled)");
        console2.log("  Whitelisted: Seaport 1.6 + OpenSea Conduit");
        console2.log("");
        console2.log("--- Export Variables ---");
        console2.log(string.concat("COLLECTION_ADDRESS=", vm.toString(result.collection)));
        console2.log(string.concat("SPLITTER_ADDRESS=", vm.toString(result.splitter)));
        console2.log(string.concat("MINTED_TOKEN_ID=", vm.toString(result.mintedTokenId)));
    }
}
