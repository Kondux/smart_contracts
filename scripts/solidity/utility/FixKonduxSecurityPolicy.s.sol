// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {KonduxImplementation} from "contracts/KonduxImplementation.sol";
import {ICreatorTokenTransferValidator} from "contracts/interfaces/ICreatorTokenTransferValidator.sol";

/**
 * @title FixKonduxSecurityPolicy
 * @notice CLI script to check and fix KonduxImplementation security policy, royalties, and whitelist
 * @dev Run with: forge script script/FixKonduxSecurityPolicy.s.sol --rpc-url mainnet -vvv
 *      To broadcast: forge script script/FixKonduxSecurityPolicy.s.sol --rpc-url mainnet --broadcast
 */
contract FixKonduxSecurityPolicyScript is Script {
    // Target contract to fix
    address public constant TARGET = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;

    // Limit Break's default transfer validator
    address public constant DEFAULT_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

    // OpenSea Seaport 1.6
    address public constant SEAPORT_16 = 0x0000000000000068F116a894984e2DB1123eB395;

    // Target royalty: 10% = 1000 basis points
    uint96 public constant TARGET_ROYALTY_BP = 1000;

    // Denominator for basis points
    uint96 public constant DENOMINATOR = 10_000;

    struct DiagnosticResult {
        // Transfer validator
        address transferValidator;
        bool validatorIsDefault;

        // Security policy
        uint8 rulesetId;
        uint48 listId;
        bool securityPolicyConfigured;

        // Royalty info
        address royaltyReceiver;
        uint256 royaltyAmount; // per 10000 sale
        uint96 royaltyBP;
        bool royaltyIs10Percent;

        // Cuts
        uint96 manufacturerCutBP;
        uint96 partnerCutBP;
        uint96 creatorCutBP;
        uint96 totalCutsBP;

        // Other
        bool autoApproveValidator;
        address partnerWallet;
        address royaltySplitter;
        uint256 totalSupply;
    }

    function run() external {
        console2.log("=== KonduxImplementation Security Policy Checker & Fixer ===");
        console2.log("");
        console2.log("Target contract:", TARGET);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        // Run diagnostics
        DiagnosticResult memory diag = _runDiagnostics();
        _printDiagnostics(diag);

        // Determine what needs fixing
        bool needsSecurityPolicy = !diag.securityPolicyConfigured;
        bool needsRoyaltyFix = !diag.royaltyIs10Percent;

        console2.log("");
        console2.log("=== Required Fixes ===");

        if (!needsSecurityPolicy && !needsRoyaltyFix) {
            console2.log("No fixes required! Contract is properly configured.");
            return;
        }

        if (needsSecurityPolicy) {
            console2.log("[FIX NEEDED] Security policy not configured - will call setToDefaultSecurityPolicy()");
        }
        if (needsRoyaltyFix) {
            console2.log("[FIX NEEDED] Royalty is not 10% - will call setDefaultRoyalty() with 1000 BP");
        }

        // Check if we should broadcast
        console2.log("");
        console2.log("=== Applying Fixes ===");

        uint256 deployerKey = vm.envUint("PROD_DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);

        console2.log("Deployer address:", deployer);
        console2.log("Deployer balance:", deployer.balance);

        // Verify deployer is admin
        KonduxImplementation kondux = KonduxImplementation(payable(TARGET));
        bytes32 adminRole = kondux.DEFAULT_ADMIN_ROLE();
        bool isAdmin = kondux.hasRole(adminRole, deployer);

        if (!isAdmin) {
            console2.log("");
            console2.log("[ERROR] Deployer is NOT an admin of the contract!");
            console2.log("Cannot apply fixes without admin role.");
            revert("Deployer is not admin");
        }

        console2.log("Deployer has admin role: true");
        console2.log("");

        vm.startBroadcast(deployerKey);

        // Fix 1: Set security policy
        if (needsSecurityPolicy) {
            console2.log("Calling setToDefaultSecurityPolicy()...");
            kondux.setToDefaultSecurityPolicy();
            console2.log("  -> Security policy configured!");
            console2.log("  -> Created whitelist with Seaport 1.6");
            console2.log("  -> Set ruleset to 4 (Operator Whitelist)");
        }

        // Fix 2: Set royalty to 10% while preserving the current receiver
        if (needsRoyaltyFix) {
            // Keep the existing royalty receiver intact
            address receiver = diag.royaltyReceiver;

            console2.log("Calling setDefaultRoyalty()...");
            console2.log("  -> Receiver (preserved):", receiver);
            console2.log("  -> Fee:", TARGET_ROYALTY_BP, "BP (10%)");
            kondux.setDefaultRoyalty(receiver, TARGET_ROYALTY_BP);
            console2.log("  -> Royalty set to 10%!");
        }

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Fixes Applied Successfully ===");

        // Re-run diagnostics to confirm
        console2.log("");
        console2.log("=== Post-Fix Verification ===");
        DiagnosticResult memory postDiag = _runDiagnostics();
        _printDiagnostics(postDiag);
    }

    function _runDiagnostics() internal view returns (DiagnosticResult memory diag) {
        KonduxImplementation kondux = KonduxImplementation(payable(TARGET));

        // Transfer validator
        diag.transferValidator = kondux.getTransferValidator();
        diag.validatorIsDefault = (diag.transferValidator == DEFAULT_VALIDATOR);

        // Security policy from validator
        if (diag.transferValidator != address(0)) {
            try ICreatorTokenTransferValidator(diag.transferValidator)
                .getCollectionSecurityPolicy(TARGET) returns (
                    ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy
                ) {
                diag.rulesetId = policy.rulesetId;
                diag.listId = policy.listId;
                // Policy is configured if ruleset >= 1 (any restriction)
                diag.securityPolicyConfigured = (policy.rulesetId >= 1);
            } catch {
                // Validator doesn't support this call
                diag.securityPolicyConfigured = false;
            }
        }

        // Royalty info (test with 10000 sale price)
        (diag.royaltyReceiver, diag.royaltyAmount) = kondux.royaltyInfo(0, DENOMINATOR);
        diag.royaltyBP = uint96(diag.royaltyAmount); // Since we used 10000 as sale price
        diag.royaltyIs10Percent = (diag.royaltyBP == TARGET_ROYALTY_BP);

        // Cuts
        diag.manufacturerCutBP = kondux.manufacturerCutBP();
        diag.partnerCutBP = kondux.partnerCutBP();
        diag.creatorCutBP = kondux.creatorCutBP();
        diag.totalCutsBP = diag.manufacturerCutBP + diag.partnerCutBP + diag.creatorCutBP;

        // Other settings
        diag.autoApproveValidator = kondux.autoApproveTransfersFromValidator();
        diag.partnerWallet = kondux.partnerWallet();

        // Try to get royaltySplitter (may not exist on older implementations)
        try kondux.royaltySplitter() returns (address splitter) {
            diag.royaltySplitter = splitter;
        } catch {
            diag.royaltySplitter = address(0);
        }

        diag.totalSupply = kondux.totalSupply();
    }

    function _printDiagnostics(DiagnosticResult memory diag) internal view {
        console2.log("--- Transfer Validator ---");
        console2.log("  Validator:", diag.transferValidator);
        console2.log("  Is Default (Limit Break):", diag.validatorIsDefault ? "YES" : "NO");

        console2.log("");
        console2.log("--- Security Policy ---");
        console2.log("  Ruleset ID:", uint256(diag.rulesetId));
        console2.log("  List ID:", uint256(diag.listId));
        if (diag.securityPolicyConfigured) {
            console2.log("  Status: CONFIGURED");
            if (diag.rulesetId == 4) {
                console2.log("  Mode: Operator Whitelist (recommended)");
            } else if (diag.rulesetId == 3) {
                console2.log("  Mode: Transfer Restrictions Active");
            }
        } else {
            console2.log("  Status: NOT CONFIGURED (no transfer restrictions!)");
        }

        console2.log("");
        console2.log("--- ERC2981 Royalty ---");
        console2.log("  Receiver:", diag.royaltyReceiver);
        console2.log("  Royalty BP:", uint256(diag.royaltyBP));
        console2.log("  Royalty %:", _bpToPercent(diag.royaltyBP));
        console2.log("  Is 10%:", diag.royaltyIs10Percent ? "YES" : "NO");

        console2.log("");
        console2.log("--- Royalty Splits (internal) ---");
        console2.log("  Manufacturer:", uint256(diag.manufacturerCutBP), "BP");
        console2.log("  Partner:", uint256(diag.partnerCutBP), "BP");
        console2.log("  Creator:", uint256(diag.creatorCutBP), "BP");
        console2.log("  Total:", uint256(diag.totalCutsBP), "BP");

        console2.log("");
        console2.log("--- Other Settings ---");
        console2.log("  Auto-approve Validator:", diag.autoApproveValidator ? "YES" : "NO");
        console2.log("  Partner Wallet:", diag.partnerWallet);
        console2.log("  Royalty Splitter:", diag.royaltySplitter);
        console2.log("  Total Supply:", diag.totalSupply);
    }

    function _bpToPercent(uint96 bp) internal pure returns (string memory) {
        uint256 whole = bp / 100;
        uint256 decimal = bp % 100;

        if (decimal == 0) {
            return string(abi.encodePacked(vm.toString(whole), "%"));
        }

        if (decimal < 10) {
            return string(abi.encodePacked(vm.toString(whole), ".0", vm.toString(decimal), "%"));
        }

        return string(abi.encodePacked(vm.toString(whole), ".", vm.toString(decimal), "%"));
    }
}

/**
 * @title CheckKonduxSecurityPolicy
 * @notice Read-only version that only checks state without applying fixes
 * @dev Run with: forge script script/FixKonduxSecurityPolicy.s.sol:CheckKonduxSecurityPolicyScript --rpc-url mainnet -vvv
 */
contract CheckKonduxSecurityPolicyScript is Script {
    address public constant TARGET = 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D;
    address public constant DEFAULT_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    uint96 public constant TARGET_ROYALTY_BP = 1000;
    uint96 public constant DENOMINATOR = 10_000;

    function run() external view {
        console2.log("=== KonduxImplementation Security Policy Checker (Read-Only) ===");
        console2.log("");
        console2.log("Target contract:", TARGET);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        KonduxImplementation kondux = KonduxImplementation(payable(TARGET));

        // Transfer validator
        address validator = kondux.getTransferValidator();
        console2.log("--- Transfer Validator ---");
        console2.log("  Validator:", validator);
        console2.log("  Is Default:", validator == DEFAULT_VALIDATOR ? "YES" : "NO");

        // Security policy
        console2.log("");
        console2.log("--- Security Policy ---");
        if (validator != address(0)) {
            try ICreatorTokenTransferValidator(validator)
                .getCollectionSecurityPolicy(TARGET) returns (
                    ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy
                ) {
                console2.log("  Ruleset ID:", uint256(policy.rulesetId));
                console2.log("  List ID:", uint256(policy.listId));
                if (policy.rulesetId >= 1) {
                    console2.log("  Status: CONFIGURED");
                } else {
                    console2.log("  Status: NOT CONFIGURED (NEEDS FIX)");
                }
            } catch {
                console2.log("  Could not query security policy");
            }
        }

        // Royalty
        console2.log("");
        console2.log("--- ERC2981 Royalty ---");
        (address receiver, uint256 amount) = kondux.royaltyInfo(0, DENOMINATOR);
        console2.log("  Receiver:", receiver);
        console2.log("  Royalty BP:", amount);
        console2.log("  Is 10%:", amount == TARGET_ROYALTY_BP ? "YES" : "NO (NEEDS FIX)");

        // Cuts
        console2.log("");
        console2.log("--- Royalty Splits ---");
        console2.log("  Manufacturer:", uint256(kondux.manufacturerCutBP()), "BP");
        console2.log("  Partner:", uint256(kondux.partnerCutBP()), "BP");
        console2.log("  Creator:", uint256(kondux.creatorCutBP()), "BP");

        // Other
        console2.log("");
        console2.log("--- Other ---");
        console2.log("  Auto-approve:", kondux.autoApproveTransfersFromValidator() ? "YES" : "NO");
        console2.log("  Total Supply:", kondux.totalSupply());

        // Summary
        console2.log("");
        console2.log("=== SUMMARY ===");

        bool needsSecurityPolicy;
        try ICreatorTokenTransferValidator(validator)
            .getCollectionSecurityPolicy(TARGET) returns (
                ICreatorTokenTransferValidator.CollectionSecurityPolicy memory policy
            ) {
            needsSecurityPolicy = (policy.rulesetId < 1);
        } catch {
            needsSecurityPolicy = true;
        }

        bool needsRoyaltyFix = (amount != TARGET_ROYALTY_BP);

        if (needsSecurityPolicy) {
            console2.log("[!] Security policy needs configuration");
        }
        if (needsRoyaltyFix) {
            console2.log("[!] Royalty needs to be set to 10%");
        }
        if (!needsSecurityPolicy && !needsRoyaltyFix) {
            console2.log("[OK] Contract is properly configured!");
        } else {
            console2.log("");
            console2.log("To apply fixes, run:");
            console2.log("  forge script script/FixKonduxSecurityPolicy.s.sol --rpc-url mainnet --broadcast");
        }
    }
}
