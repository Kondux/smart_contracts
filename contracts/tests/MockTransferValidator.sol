// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../vendor/limitbreak/interfaces/ITransferValidator.sol";

contract MockTransferValidator is ITransferValidator {
    error MockTransferValidator__Rejected();

    struct Expectation {
        address caller;
        address from;
        address to;
        uint256 tokenId;
        bool isSet;
    }

    Expectation private _expectation;
    bool public shouldRevert;

    function setExpectation(address caller, address from, address to, uint256 tokenId) external {
        _expectation = Expectation({caller: caller, from: from, to: to, tokenId: tokenId, isSet: true});
    }

    function clearExpectation() external {
        if (_expectation.isSet) {
            delete _expectation;
        }
    }

    function setShouldRevert(bool value) external {
        shouldRevert = value;
    }

    function currentExpectation() external view returns (Expectation memory) {
        return _expectation;
    }

    // ---------------------------------------------------------------------
    // ITransferValidator hooks
    // ---------------------------------------------------------------------
    function applyCollectionTransferPolicy(address, address, address) external view override {}

    function validateTransfer(address, address, address) external view override {}

    function validateTransfer(address caller, address from, address to, uint256 tokenId) external view override {
        _validate(caller, from, to, tokenId);
    }

    function validateTransfer(address caller, address from, address to, uint256 tokenId, uint256)
        external
        view
        override
    {
        _validate(caller, from, to, tokenId);
    }

    function beforeAuthorizedTransfer(address, address, uint256) external view override {}

    function afterAuthorizedTransfer(address, uint256) external view override {}

    function beforeAuthorizedTransfer(address, address) external view override {}

    function afterAuthorizedTransfer(address) external view override {}

    function beforeAuthorizedTransfer(address, uint256) external view override {}

    function beforeAuthorizedTransferWithAmount(address, uint256, uint256) external view override {}

    function afterAuthorizedTransferWithAmount(address, uint256) external view override {}

    function _validate(address caller, address from, address to, uint256 tokenId) private view {
        if (shouldRevert) {
            revert MockTransferValidator__Rejected();
        }

        if (_expectation.isSet) {
            require(caller == _expectation.caller, "MockValidator: caller");
            require(from == _expectation.from, "MockValidator: from");
            require(to == _expectation.to, "MockValidator: to");
            require(tokenId == _expectation.tokenId, "MockValidator: tokenId");
        }
    }
}
