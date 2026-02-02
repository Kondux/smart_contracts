// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";

/**
 * @title ConfigureOpenSeaSecurity
 * @notice Configures the security policy for a Kondux collection to enforce OpenSea operator restrictions
 * @dev Calls setToDefaultSecurityPolicy() which:
 *      1. Sets transfer security level to 3 (OperatorWhitelistEnableOTC)
 *      2. Creates/assigns a whitelist with Seaport enabled
 *      3. Adds OpenSea Conduit to the whitelist
 *
 * Security Level 3 means:
 *   - Only whitelisted operators (OpenSea/Seaport) can transfer during sales
 *   - OTC (peer-to-peer) transfers are still allowed
 *   - Prevents trading on non-whitelisted marketplaces
 *
 * NOTE: This does NOT force OpenSea to collect royalties. OpenSea's UI still allows
 * sellers to opt-out of creator fees. However, trades can ONLY happen through
 * whitelisted operators.
 *
 * Usage:
 *   # Dry-run
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=<pk> \
 *     COLLECTION_ADDRESS=0xb9e5dF49c372096AA490E8B14111Ad0D85eB71b6 \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/ConfigureOpenSeaSecurity.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf'"
 *
 *   # Broadcast
 *   wsl -e bash -c "cd /mnt/d/git/smart_contracts && \
 *     PROD_DEPLOYER_PK=<pk> \
 *     COLLECTION_ADDRESS=0xb9e5dF49c372096AA490E8B14111Ad0D85eB71b6 \
 *     ~/.foundry/bin/forge script scripts/solidity/deploy/ConfigureOpenSeaSecurity.s.sol \
 *     --rpc-url 'https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf' --broadcast"
 */
contract ConfigureOpenSeaSecurity is Script {
    // Transfer Validator V5
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    
    // OpenSea addresses
    address constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address constant SEAPORT = 0x0000000000000068F116a894984e2DB1123eB395;
    // OpenSea SignedZone (Mainnet) - required for ERC721C compliance
    address constant SIGNED_ZONE = 0x000056F7000000EcE9003ca63978907a00FFD100;

    function run() external {
        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);
        address collectionAddr = vm.envAddress("COLLECTION_ADDRESS");

        console2.log("=== Configure OpenSea Security Policy ===");
        console2.log("Collection:", collectionAddr);
        console2.log("Deployer:", deployer);
        console2.log("");

        KonduxImplementation collection = KonduxImplementation(payable(collectionAddr));

        // Check current state
        address validator = collection.getTransferValidator();
        console2.log("Current Transfer Validator:", validator);
        
        if (validator == address(0)) {
            console2.log("WARNING: No transfer validator set!");
        }

        console2.log("");
        console2.log("Setting default security policy...");
        console2.log("  - Security Level: 3 (OperatorWhitelistEnableOTC)");
        console2.log("  - Whitelisted: Seaport + OpenSea Conduit");
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Set the default security policy
        // This calls the Transfer Validator to configure the collection
        collection.setToDefaultSecurityPolicy();

        // Add SignedZone as Authorizer (for ERC721C compliance)
        address[] memory authorizers = new address[](1);
        authorizers[0] = SIGNED_ZONE;
        (bool success, ) = address(collection).call(
            abi.encodeWithSignature("addAccountsToAuthorizers(address[])", authorizers)
        );
        if (success) {
            console2.log("Authorized SignedZone");
        } else {
            console2.log("WARNING: Failed to authorize SignedZone (function missing?)");
        }

        vm.stopBroadcast();

        // Verify
        console2.log("Verifying configuration...");
        validator = collection.getTransferValidator();
        console2.log("  Transfer Validator:", validator);
        
        if (validator == TRANSFER_VALIDATOR_V5) {
            console2.log("  PASS: V5 Transfer Validator confirmed");
        }

        console2.log("");
        console2.log("=== DONE ===");
        console2.log("Collection is now configured with operator whitelist.");
        console2.log("Only OpenSea/Seaport can facilitate trades.");
        console2.log("");
        console2.log("NOTE: OpenSea UI may still allow sellers to set 0% creator fee.");
        console2.log("This is an OpenSea policy decision, not a blockchain restriction.");
    }
}
