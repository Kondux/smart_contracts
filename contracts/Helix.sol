// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./interfaces/IStaking.sol";
import "./types/AccessControlled.sol";

contract Helix is ERC20, AccessControlled {

    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");

    IStaking public staking;

    constructor(string memory _name, string memory _ticker, address _authority) 
        ERC20(_name, _ticker) 
        AccessControlled(IAuthority(_authority)) {
    }

    function mint(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _burn(_to, _amount);
    }

    function setStaking(address _staking) public onlyGovernor {
        staking = IStaking(_staking);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20) {
        if (from != address(0) && to != address(0)) { // not a mint or burn
            require(staking.getStakedAmount(to) > 0, "Only Stakers can receive tokens");
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}