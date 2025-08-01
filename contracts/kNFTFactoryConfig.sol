// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFactoryConfig.sol";

contract kNFTFactoryConfig is Ownable, IFactoryConfig {
    constructor() Ownable(msg.sender) {}

    bool    public override factoryActive = true;
    bool    public override feeEnabled    = false;
    bool    public override restricted    = false;
    uint256 public override creationFee   = 0.05 ether;
    mapping(address => bool) public override freeCreators;

    /* ------------ setters (owner‑only) ------------- */
    function setFactoryActive(bool v) external onlyOwner { factoryActive = v; }
    function setFeeEnabled(bool v)    external onlyOwner { feeEnabled  = v; }
    function setRestricted(bool v)    external onlyOwner { restricted  = v; }
    function setCreationFee(uint256 v) external onlyOwner { creationFee = v; }
    function setFreeCreator(address who, bool isFree)
        external
        onlyOwner
    {   freeCreators[who] = isFree; }
}
