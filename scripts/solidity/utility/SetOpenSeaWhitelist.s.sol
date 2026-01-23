// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {ICreatorTokenTransferValidator} from "contracts/interfaces/ICreatorTokenTransferValidator.sol";

/**
 * @title SetOpenSeaWhitelist
 * @notice Script to create/apply a whitelist with OpenSea conduit + Seaport addresses for royalty enforcement
 * @dev This script:
 *      1. Creates a new whitelist on the transfer validator
 *      2. Adds OpenSea conduit + Seaport 1.6/1.5/1.4/1.1 to the whitelist
 *      3. Applies the whitelist to the target collection
 *      4. Sets ruleset to 4 (Operator Whitelist, OTC disabled)
 *
 * Usage:
 *   # Dry run (read-only check)
 *   forge script scripts/solidity/utility/SetOpenSeaWhitelist.s.sol:CheckOpenSeaWhitelistScript \
 *       --rpc-url mainnet -vvv
 *
 *   # Apply changes
 *   forge script scripts/solidity/utility/SetOpenSeaWhitelist.s.sol \
 *       --rpc-url mainnet --broadcast -vvv
 *
 * Environment variables:
 *   PROD_DEPLOYER_PK - Private key of admin wallet
 *   TARGET_COLLECTION - (Optional) Override target collection address
 */
contract SetOpenSeaWhitelistScript is Script {
    // Default target - Kondux Omniforge mainnet
    address public constant DEFAULT_TARGET = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;

    // Limit Break's default transfer validator
    address public constant DEFAULT_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    // ============ OpenSea / Seaport Addresses ============
    // OpenSea Conduit (handles token transfers on behalf of Seaport)
    address public constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    // Seaport versions (OpenSea's exchange contracts)
    address public constant SEAPORT_16 = 0x0000000000000068F116a894984e2DB1123eB395; // Latest
    address public constant SEAPORT_15 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address public constant SEAPORT_14 = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address public constant SEAPORT_11 = 0x00000000006c3852cbEf3e08E8dF289169EdE581;

    // List type constants
    uint8 public constant LIST_TYPE_WHITELIST = 1;

    // Ruleset 4 = Operator Whitelist with OTC disabled (recommended for royalty enforcement)
    uint8 public constant RULESET_OPERATOR_WHITELIST = 4;

    function run() external {
        address target = vm.envOr("TARGET_COLLECTION", DEFAULT_TARGET);

        console2.log("=== SetOpenSeaWhitelist Script ===");
        console2.log("");
        console2.log("Target collection:", target);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        KonduxImplementation kondux = KonduxImplementation(payable(target));

        // Check current state
        address validator = kondux.getTransferValidator();
        console2.log("--- Current State ---");
        console2.log("Transfer Validator:", validator);

        if (validator == address(0)) {
            console2.log("[ERROR] No transfer validator set on collection!");
            console2.log("The collection must have a transfer validator to use whitelists.");
            revert("No transfer validator");
        }

        if (validator != DEFAULT_VALIDATOR) {
            console2.log("[WARNING] Non-default validator detected.");
            console2.log("Expected:", DEFAULT_VALIDATOR);
            console2.log("This script is designed for Limit Break's default validator.");
        }

        // Get current security policy
        ICreatorTokenTransferValidator validatorContract = ICreatorTokenTransferValidator(validator);
        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory currentPolicy;

        try validatorContract.getCollectionSecurityPolicy(target) returns (
            ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy
        ) {
            currentPolicy = policy;
            console2.log("Current Ruleset ID:", uint256(policy.rulesetId));
            console2.log("Current List ID:", uint256(policy.listId));
        } catch {
            console2.log("Could not query current security policy");
        }

        // Check which addresses are already whitelisted (if list exists)
        if (currentPolicy.listId > 0) {
            console2.log("");
            console2.log("--- Current Whitelist Status (List", uint256(currentPolicy.listId), ") ---");
            _checkWhitelistStatus(validatorContract, uint48(currentPolicy.listId));
        }

        // Prepare to apply changes
        console2.log("");
        console2.log("=== Applying OpenSea Whitelist ===");

        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("Deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance);

        // Verify deployer is admin
        bytes32 adminRole = kondux.DEFAULT_ADMIN_ROLE();
        bool isAdmin = kondux.hasRole(adminRole, deployer);

        if (!isAdmin) {
            console2.log("");
            console2.log("[ERROR] Deployer is NOT an admin of the collection!");
            revert("Deployer is not admin");
        }
        console2.log("Deployer has admin role: YES");

        vm.startBroadcast(deployerKey);

        // Step 1: Create a new whitelist
        console2.log("");
        console2.log("Step 1: Creating new whitelist...");
        uint48 newListId = validatorContract.createList("");
        console2.log("  -> Created list ID:", uint256(newListId));

        // Step 2: Add OpenSea conduit + all Seaport versions to whitelist
        console2.log("");
        console2.log("Step 2: Adding OpenSea/Seaport addresses to whitelist...");

        address[] memory operatorsToAdd = new address[](5);
        operatorsToAdd[0] = OPENSEA_CONDUIT;
        operatorsToAdd[1] = SEAPORT_16;
        operatorsToAdd[2] = SEAPORT_15;
        operatorsToAdd[3] = SEAPORT_14;
        operatorsToAdd[4] = SEAPORT_11;

        validatorContract.addAccountsToList(uint48(newListId), LIST_TYPE_WHITELIST, operatorsToAdd);

        console2.log("  -> Added OpenSea Conduit:", OPENSEA_CONDUIT);
        console2.log("  -> Added Seaport 1.6:", SEAPORT_16);
        console2.log("  -> Added Seaport 1.5:", SEAPORT_15);
        console2.log("  -> Added Seaport 1.4:", SEAPORT_14);
        console2.log("  -> Added Seaport 1.1:", SEAPORT_11);

        // Step 3: Apply the list to the collection
        console2.log("");
        console2.log("Step 3: Applying whitelist to collection...");
        validatorContract.applyListToCollection(target, newListId);
        console2.log("  -> List", uint256(newListId), "applied to collection");

        // Step 4: Set ruleset to 4 (Operator Whitelist)
        console2.log("");
        console2.log("Step 4: Setting ruleset to Operator Whitelist (4)...");
        validatorContract.setTransferSecurityLevelOfCollection(target, RULESET_OPERATOR_WHITELIST);
        console2.log("  -> Ruleset set to 4 (Operator Whitelist, OTC disabled)");

        vm.stopBroadcast();

        // Verify final state
        console2.log("");
        console2.log("=== Post-Apply Verification ===");

        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory finalPolicy =
            validatorContract.getCollectionSecurityPolicy(target);

        console2.log("Final Ruleset ID:", uint256(finalPolicy.rulesetId));
        console2.log("Final List ID:", uint256(finalPolicy.listId));

        console2.log("");
        console2.log("--- Final Whitelist Status ---");
        _checkWhitelistStatus(validatorContract, uint48(finalPolicy.listId));

        console2.log("");
        console2.log("=== SUCCESS ===");
        console2.log("OpenSea whitelist has been configured for royalty enforcement.");
        console2.log("");
        console2.log("What this means:");
        console2.log("  - Only whitelisted operators (OpenSea/Seaport) can transfer tokens");
        console2.log("  - Direct OTC transfers are disabled (prevents royalty bypass)");
        console2.log("  - OpenSea will enforce royalties on sales");
    }

    function _checkWhitelistStatus(ICreatorTokenTransferValidator validator, uint48 listId) internal view {
        console2.log("OpenSea Conduit:", _isWhitelisted(validator, listId, OPENSEA_CONDUIT));
        console2.log("Seaport 1.6:", _isWhitelisted(validator, listId, SEAPORT_16));
        console2.log("Seaport 1.5:", _isWhitelisted(validator, listId, SEAPORT_15));
        console2.log("Seaport 1.4:", _isWhitelisted(validator, listId, SEAPORT_14));
        console2.log("Seaport 1.1:", _isWhitelisted(validator, listId, SEAPORT_11));
    }

    function _isWhitelisted(ICreatorTokenTransferValidator validator, uint48 listId, address account)
        internal
        view
        returns (string memory)
    {
        try validator.isAccountInList(listId, LIST_TYPE_WHITELIST, account) returns (bool result) {
            return result ? "YES" : "NO";
        } catch {
            return "ERROR";
        }
    }
}

/**
 * @title CheckOpenSeaWhitelistScript
 * @notice Read-only version - checks current whitelist state without making changes
 */
contract CheckOpenSeaWhitelistScript is Script {
    address public constant DEFAULT_TARGET = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;
    address public constant DEFAULT_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    address public constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address public constant SEAPORT_16 = 0x0000000000000068F116a894984e2DB1123eB395;
    address public constant SEAPORT_15 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address public constant SEAPORT_14 = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address public constant SEAPORT_11 = 0x00000000006c3852cbEf3e08E8dF289169EdE581;

    uint8 public constant LIST_TYPE_WHITELIST = 1;

    function run() external view {
        address target = vm.envOr("TARGET_COLLECTION", DEFAULT_TARGET);

        console2.log("=== OpenSea Whitelist Checker (Read-Only) ===");
        console2.log("");
        console2.log("Target collection:", target);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        KonduxImplementation kondux = KonduxImplementation(payable(target));
        address validator = kondux.getTransferValidator();

        console2.log("--- Transfer Validator ---");
        console2.log("Validator:", validator);
        console2.log("Is Default:", validator == DEFAULT_VALIDATOR ? "YES" : "NO");

        if (validator == address(0)) {
            console2.log("");
            console2.log("[ERROR] No transfer validator set!");
            return;
        }

        ICreatorTokenTransferValidator validatorContract = ICreatorTokenTransferValidator(validator);

        console2.log("");
        console2.log("--- Security Policy ---");

        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy;
        try validatorContract.getCollectionSecurityPolicy(target) returns (
            ICreatorTokenTransferValidator.CollectionSecurityPolicy memory p
        ) {
            policy = p;
            console2.log("Ruleset ID:", uint256(policy.rulesetId));
            console2.log("List ID:", uint256(policy.listId));

            if (policy.rulesetId == 0) {
                console2.log("Status: NOT CONFIGURED (no transfer restrictions)");
            } else if (policy.rulesetId == 4) {
                console2.log("Status: Operator Whitelist (recommended)");
            } else {
                console2.log("Status: Configured with ruleset", uint256(policy.rulesetId));
            }
        } catch {
            console2.log("Could not query security policy");
            return;
        }

        if (policy.listId == 0) {
            console2.log("");
            console2.log("[!] No whitelist applied to collection");
            console2.log("");
            console2.log("To fix, run:");
            console2.log("  forge script scripts/solidity/utility/SetOpenSeaWhitelist.s.sol --rpc-url mainnet --broadcast -vvv");
            return;
        }

        console2.log("");
        console2.log("--- Whitelist Status (List", uint256(policy.listId), ") ---");

        _printWhitelistStatus(validatorContract, uint48(policy.listId), "OpenSea Conduit", OPENSEA_CONDUIT);
        _printWhitelistStatus(validatorContract, uint48(policy.listId), "Seaport 1.6", SEAPORT_16);
        _printWhitelistStatus(validatorContract, uint48(policy.listId), "Seaport 1.5", SEAPORT_15);
        _printWhitelistStatus(validatorContract, uint48(policy.listId), "Seaport 1.4", SEAPORT_14);
        _printWhitelistStatus(validatorContract, uint48(policy.listId), "Seaport 1.1", SEAPORT_11);

        // Summary
        console2.log("");
        console2.log("=== SUMMARY ===");

        bool hasConduit = _isWhitelisted(validatorContract, uint48(policy.listId), OPENSEA_CONDUIT);
        bool hasSeaport16 = _isWhitelisted(validatorContract, uint48(policy.listId), SEAPORT_16);
        bool hasSeaport15 = _isWhitelisted(validatorContract, uint48(policy.listId), SEAPORT_15);

        if (hasConduit && (hasSeaport16 || hasSeaport15)) {
            console2.log("[OK] OpenSea whitelist is properly configured for royalty enforcement!");
        } else {
            console2.log("[!] OpenSea whitelist is INCOMPLETE");
            if (!hasConduit) {
                console2.log("  -> Missing: OpenSea Conduit");
            }
            if (!hasSeaport16 && !hasSeaport15) {
                console2.log("  -> Missing: Seaport contract (1.6 or 1.5)");
            }
            console2.log("");
            console2.log("To fix, run:");
            console2.log("  forge script scripts/solidity/utility/SetOpenSeaWhitelist.s.sol --rpc-url mainnet --broadcast -vvv");
        }
    }

    function _printWhitelistStatus(
        ICreatorTokenTransferValidator validator,
        uint48 listId,
        string memory name,
        address account
    ) internal view {
        bool whitelisted = _isWhitelisted(validator, listId, account);
        console2.log(name, whitelisted ? "YES" : "NO");
    }

    function _isWhitelisted(ICreatorTokenTransferValidator validator, uint48 listId, address account)
        internal
        view
        returns (bool)
    {
        try validator.isAccountInList(listId, LIST_TYPE_WHITELIST, account) returns (bool result) {
            return result;
        } catch {
            return false;
        }
    }
}

/**
 * @title AddToExistingWhitelistScript
 * @notice Adds OpenSea/Seaport addresses to an EXISTING whitelist without creating a new one
 * @dev Use this if you already have a whitelist and just need to add missing addresses
 *
 * Usage:
 *   forge script scripts/solidity/utility/SetOpenSeaWhitelist.s.sol:AddToExistingWhitelistScript \
 *       --rpc-url mainnet --broadcast -vvv
 */
contract AddToExistingWhitelistScript is Script {
    address public constant DEFAULT_TARGET = 0xaA030Da0C99726F83E9959b450482Fb00216C26D;
    address public constant DEFAULT_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    address public constant OPENSEA_CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;
    address public constant SEAPORT_16 = 0x0000000000000068F116a894984e2DB1123eB395;
    address public constant SEAPORT_15 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address public constant SEAPORT_14 = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address public constant SEAPORT_11 = 0x00000000006c3852cbEf3e08E8dF289169EdE581;

    uint8 public constant LIST_TYPE_WHITELIST = 1;

    function run() external {
        address target = vm.envOr("TARGET_COLLECTION", DEFAULT_TARGET);

        console2.log("=== Add to Existing Whitelist Script ===");
        console2.log("");
        console2.log("Target collection:", target);

        KonduxImplementation kondux = KonduxImplementation(payable(target));
        address validator = kondux.getTransferValidator();

        require(validator != address(0), "No transfer validator");

        ICreatorTokenTransferValidator validatorContract = ICreatorTokenTransferValidator(validator);

        ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy =
            validatorContract.getCollectionSecurityPolicy(target);

        require(policy.listId > 0, "No whitelist applied - use SetOpenSeaWhitelistScript instead");

        uint48 listId = uint48(policy.listId);
        console2.log("Existing List ID:", uint256(listId));

        // Check which addresses need to be added
        address[] memory toAdd = new address[](5);
        uint256 count = 0;

        if (!_isWhitelisted(validatorContract, listId, OPENSEA_CONDUIT)) {
            toAdd[count++] = OPENSEA_CONDUIT;
            console2.log("Will add: OpenSea Conduit");
        }
        if (!_isWhitelisted(validatorContract, listId, SEAPORT_16)) {
            toAdd[count++] = SEAPORT_16;
            console2.log("Will add: Seaport 1.6");
        }
        if (!_isWhitelisted(validatorContract, listId, SEAPORT_15)) {
            toAdd[count++] = SEAPORT_15;
            console2.log("Will add: Seaport 1.5");
        }
        if (!_isWhitelisted(validatorContract, listId, SEAPORT_14)) {
            toAdd[count++] = SEAPORT_14;
            console2.log("Will add: Seaport 1.4");
        }
        if (!_isWhitelisted(validatorContract, listId, SEAPORT_11)) {
            toAdd[count++] = SEAPORT_11;
            console2.log("Will add: Seaport 1.1");
        }

        if (count == 0) {
            console2.log("");
            console2.log("All OpenSea/Seaport addresses are already whitelisted!");
            return;
        }

        // Trim array to actual size
        address[] memory finalToAdd = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            finalToAdd[i] = toAdd[i];
        }

        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("");
        console2.log("Deployer:", deployer);

        // Check if deployer owns the list
        address listOwner = validatorContract.listOwners(listId);
        console2.log("List owner:", listOwner);

        if (listOwner != deployer) {
            console2.log("[ERROR] Deployer does not own list", uint256(listId));
            console2.log("Only the list owner can add accounts to the whitelist.");
            revert("Not list owner");
        }

        vm.startBroadcast(deployerKey);

        console2.log("");
        console2.log("Adding", count, "addresses to whitelist...");
        validatorContract.addAccountsToList(listId, LIST_TYPE_WHITELIST, finalToAdd);

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== SUCCESS ===");
        console2.log("Added", count, "addresses to whitelist", uint256(listId));
    }

    function _isWhitelisted(ICreatorTokenTransferValidator validator, uint48 listId, address account)
        internal
        view
        returns (bool)
    {
        try validator.isAccountInList(listId, LIST_TYPE_WHITELIST, account) returns (bool result) {
            return result;
        } catch {
            return false;
        }
    }
}
