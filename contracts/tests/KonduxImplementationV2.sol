// SPDX‑License‑Identifier: GPL‑3.0‑or‑later
pragma solidity ^0.8.30;

import "../KonduxImplementation.sol";

/**
 * @title KonduxImplementationV2
 * @notice A minimal upgrade that keeps the exact storage layout of
 *         KonduxImplementation but exposes a `version()` getter so tests
 *         can prove they are running against the new logic.
 *
 *         ▸ All inherited functionality (including the UUPS `authorizeUpgrade`
 *           guard) remains unchanged.
 */
contract KonduxImplementationV2 is KonduxImplementation {
    /// @dev Simple marker used only by the test‑suite.
    function version() external pure returns (string memory) {
        return "V2";
    }
}
