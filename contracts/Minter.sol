// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IKondux.sol";

import "./types/AccessControlled.sol";

import "hardhat/console.sol";

contract Minter is AccessControlled {

    uint256 public price;

    IKondux public immutable kondux;

    constructor(address _authority, address _kondux) 
        AccessControlled(IAuthority(_authority)) {        
            require(_kondux != address(0), "Kondux address is not set");
            kondux = IKondux(_kondux);
    }

    receive() external payable {
        console.log("Minter received");
        console.log("Minter received", address(this).balance);
        console.log("Minter received", msg.value);
        console.log("Minter received", msg.sender);
        _mint();
    }

    function setPrice(uint256 _price) public onlyGovernor {
        console.log("setPrice", _price);
        price = _price;
    }

    // ** INTERNAL FUNCTIONS **

    function _mint() internal {
        require(msg.value >= price, "Not enought ether");
        console.log("_mint", msg.sender, msg.value, price);
        kondux.automaticMint(msg.sender);
    }

}