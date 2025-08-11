// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title MockAuthority
 * @notice A minimal implementation of the Authority interface used by the
 *         KonduxBatchMinter contract. The real Authority contract is
 *         expected to return the address of the vault where minting fees
 *         should be forwarded. In this mock implementation the vault
 *         address is supplied at construction time and returned via the
 *         `vault()` function. This contract is deliberately simple and
 *         suitable for local and test deployments where the full
 *         functionality of an Authority contract is unnecessary.
 */
contract MockAuthority {
    /// @dev The address to which minting fees will be forwarded.
    address private immutable _vault;

    /**
     * @notice Constructs a new MockAuthority.
     * @param vault_ The address of the vault to which fees should be sent.
     */
    constructor(address vault_) {
        require(vault_ != address(0), "MockAuthority: vault is zero address");
        _vault = vault_;
    }

    /**
     * @notice Returns the address of the vault.
     * @dev Mimics the interface expected by KonduxBatchMinter. When using a
     *      full Authority implementation this function would likely include
     *      additional access control or business logic.
     * @return The configured vault address.
     */
    function vault() external view returns (address) {
        return _vault;
    }
}