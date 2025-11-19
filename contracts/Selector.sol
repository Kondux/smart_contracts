// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Selector {
    error CreatorTokenBase__InvalidTransferValidatorContract();
    function getSelector() public pure returns (bytes4) {
        return CreatorTokenBase__InvalidTransferValidatorContract.selector;
    }
}
