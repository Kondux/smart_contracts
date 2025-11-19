// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ICreatorTokenTransferValidator {
    struct CollectionSecurityPolicy {
        uint8 rulesetId;
        uint48 listId;
        address customRuleset;
        uint8 globalOptions;
        uint16 rulesetOptions;
        uint16 tokenType;
    }

    function createList(string calldata name) external returns (uint48);
    function addAccountsToList(uint48 id, uint8 listType, address[] calldata accounts) external;
    function applyListToCollection(address collection, uint48 id) external;
    function setRulesetOfCollection(
        address collection,
        uint8 rulesetId,
        address customRuleset,
        uint8 globalOptions,
        uint16 rulesetOptions
    ) external;
    function getCollectionSecurityPolicy(address collection) external view returns (CollectionSecurityPolicy memory);
    function freezeAccountsForCollection(address collection, address[] memory accountsToFreeze) external;
    function unfreezeAccountsForCollection(address collection, address[] memory accountsToUnfreeze) external;
}
