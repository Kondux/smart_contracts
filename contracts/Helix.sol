// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17; 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";


contract Helix is ERC20, AccessControl {
    // Define the roles
    bytes32 public constant ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Flag to enable or disable unrestricted transfers
    bool public enableUnrestrictedTransfers;

    // Whitelist of allowed contracts
    mapping(address => bool) public allowedContracts;

    constructor(string memory _name, string memory _ticker) ERC20(_name, _ticker) {        
        enableUnrestrictedTransfers = false;
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender); 
    }

     // Modifiers for checking roles
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "HelixToken: only admin");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "HelixToken: only minter");
        _;
    }

    modifier onlyBurner() {
        require(hasRole(BURNER_ROLE, msg.sender), "HelixToken: only burner");
        _;
    }

    // Add or remove a contract from the whitelist 
    function setAllowedContract(address contractAddress, bool allowed) public onlyAdmin {
        allowedContracts[contractAddress] = allowed;
    }

    // Check if an address is a contract by examining its code size
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    // Check if a contract is whitelisted
    function isWhitelistedContract(address addr) internal view returns (bool) {
        if (!isContract(addr)) {
            return false;
        }
        return allowedContracts[addr];
    }

    // Override the _beforeTokenTransfer function from the ERC20 contract
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        // Allow minting and burning
        if (from == address(0) || to == address(0)) {
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        // Allow transfers initiated by whitelisted contracts on behalf of users or when unrestricted transfers are enabled
        if (isWhitelistedContract(msg.sender) || enableUnrestrictedTransfers) {
            console.log("Whitelisted contract or unrestricted transfers enabled");
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        // Disallow all other transfers
        revert("HelixToken: direct transfers not allowed");
    }

    // Expose mint and burn functions only to the corresponding roles
    function mint(address to, uint256 amount) public onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyBurner {
        _burn(from, amount);
    }

    // Toggle the enableUnrestrictedTransfers flag
    function setEnableUnrestrictedTransfers(bool enabled) public onlyAdmin {
        enableUnrestrictedTransfers = enabled;
    }

    // Add or remove a role from an address
    function setRole(bytes32 role, address addr, bool enabled) public onlyAdmin {
        if (enabled) {
            _grantRole(role, addr);
        } else {
            _revokeRole(role, addr);
        }
    }
}
