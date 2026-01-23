// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IOperatorFilterRegistry
 * @notice Interface for OpenSea's Operator Filter Registry
 * @dev Registry address: 0x000000000000AAeB6D7670E522A718067333cd4E (mainnet & most L2s)
 *      Default subscription: 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6 (OpenSea curated list)
 */
interface IOperatorFilterRegistry {
    /**
     * @notice Returns true if the contract is registered with the registry.
     */
    function isRegistered(address addr) external view returns (bool);

    /**
     * @notice Registers an address with the registry and subscribes to another address's filtered operators.
     * @param registrant Address to register.
     * @param subscription Address to subscribe to for filtered operators.
     */
    function registerAndSubscribe(address registrant, address subscription) external;

    /**
     * @notice Registers an address with the registry without subscribing to any list.
     * @param registrant Address to register.
     */
    function register(address registrant) external;

    /**
     * @notice Registers an address with the registry and copies the filtered operators from another address.
     * @param registrant Address to register.
     * @param registrantToCopy Address to copy filtered operators from.
     */
    function registerAndCopyEntries(address registrant, address registrantToCopy) external;

    /**
     * @notice Subscribes an already-registered address to another address's filtered operators.
     * @param registrant Address that is already registered.
     * @param subscription Address to subscribe to.
     */
    function subscribe(address registrant, address subscription) external;

    /**
     * @notice Unsubscribes an address from its current subscription and copies the filtered operators.
     * @param registrant Address to unsubscribe.
     * @param copyExistingEntries If true, copies filtered operators from the subscription.
     */
    function unsubscribe(address registrant, bool copyExistingEntries) external;

    /**
     * @notice Returns the subscription address for a registrant.
     */
    function subscriptionOf(address registrant) external view returns (address);

    /**
     * @notice Returns true if the operator is allowed for the given registrant.
     */
    function isOperatorAllowed(address registrant, address operator) external view returns (bool);

    /**
     * @notice Updates an operator's filtered status for a registrant.
     * @param registrant The registrant address.
     * @param operator The operator address to update.
     * @param filtered True to filter (block), false to allow.
     */
    function updateOperator(address registrant, address operator, bool filtered) external;

    /**
     * @notice Updates multiple operators' filtered status for a registrant.
     */
    function updateOperators(address registrant, address[] calldata operators, bool filtered) external;

    /**
     * @notice Updates a code hash's filtered status for a registrant.
     */
    function updateCodeHash(address registrant, bytes32 codeHash, bool filtered) external;

    /**
     * @notice Updates multiple code hashes' filtered status for a registrant.
     */
    function updateCodeHashes(address registrant, bytes32[] calldata codeHashes, bool filtered) external;

    /**
     * @notice Returns the list of filtered operators for a registrant.
     */
    function filteredOperators(address registrant) external view returns (address[] memory);

    /**
     * @notice Returns the list of filtered code hashes for a registrant.
     */
    function filteredCodeHashes(address registrant) external view returns (bytes32[] memory);

    /**
     * @notice Returns true if the operator is filtered for the given registrant.
     */
    function isOperatorFiltered(address registrant, address operator) external view returns (bool);

    /**
     * @notice Returns true if the code hash is filtered for the given registrant.
     */
    function isCodeHashFiltered(address registrant, bytes32 codeHash) external view returns (bool);
}
