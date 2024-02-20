// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IHelix.sol";

contract MinterContract {
    function transferTokens(IHelix token, address from, address to, uint256 amount) external {
        require(token.allowance(from, address(this)) >= amount, "MinterContract: allowance not enough");
        token.transferFrom(from, to, amount);
    }
    function mint(IHelix token, address to, uint256 amount) external {
        token.mint(to, amount);  
    }
}