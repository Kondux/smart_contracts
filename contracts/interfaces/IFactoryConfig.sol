// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @dev Read‑only interface used by kNFTFactoryV2
 */
interface IFactoryConfig {
    function factoryActive() external view returns (bool);
    function feeEnabled()    external view returns (bool);
    function restricted()    external view returns (bool);
    function creationFee()   external view returns (uint256);
    function freeCreators(address) external view returns (bool);
}
