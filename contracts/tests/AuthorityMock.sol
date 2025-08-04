// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @dev Minimal stub used only by the tests.
 *      The real Authority contract just needs to expose `vault()`.
 */
contract AuthorityMock {
    address public vault;

    constructor(address _vault) {
        vault = _vault;
    }

    /** test helper – change the vault address after deployment */
    function setVault(address _vault) external {
        vault = _vault;
    }
}