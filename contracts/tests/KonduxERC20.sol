// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KonduxERC20 is ERC20 {

    constructor() ERC20("KonduxERC20", "KonduxERC20") {
        faucet();
    }

    function faucet() public {
        _mint(msg.sender, 100_000_000_000 * (10 ** 18));
    }
}
