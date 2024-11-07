// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockKonduxERC20 is ERC20 {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("MockKonduxToken", "MKNDX") {
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
