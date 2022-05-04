// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IKondux.sol";
import "./types/AccessControlled.sol";

contract Minter is AccessControlled {

    uint256 public price;
    bytes32 public root;

    IKondux public immutable kondux;

    constructor(address _authority, address _kondux) 
        AccessControlled(IAuthority(_authority)) {        
            require(_kondux != address(0), "Kondux address is not set");
            kondux = IKondux(_kondux);
    }

    receive() external payable {
        _mint();
    }

    function unsafeMint() public returns (uint256) {
        uint256 id = _unsafeMint();
        return id;

    }        

    function setPrice(uint256 _price) public onlyGovernor {
        price = _price;
    }

    function whitelistMint(bytes32[] calldata _merkleProof) public returns (uint256) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, root, leaf), "Incorrect proof");
        return _unsafeMint();
    }

    function setRoot(bytes32 _root) public onlyGovernor {
        root = _root;
    }

    // ** INTERNAL FUNCTIONS **

    function _mint() internal {
        require(msg.value >= price, "Not enought ether");
        kondux.automaticMint(msg.sender);
    }

    function _unsafeMint() internal returns (uint256) {
        uint256 id = kondux.automaticMint(msg.sender);
        return id;
    }

}