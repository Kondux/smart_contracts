// contracts/mocks/MockKonduxERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MockKonduxERC20 is ERC20 {

    constructor() ERC20("MockKonduxToken", "MKNDX") {
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
