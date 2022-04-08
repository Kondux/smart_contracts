// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./verifySignature.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TimeLock is VerifySignature, Ownable{

    event SetApprove(uint indexed blocknumber);
    event SetSigner(address indexed signer);

    address public signer;
    uint public blockNumber;

    constructor(address _signer) VerifySignature(){
        setSigner(_signer);
    }

    modifier authorized(){
        require(blockNumber >= block.number, "Authorization Expired");
        _;
    }

    function setSigner(address _signer) public onlyOwner{
        require(_signer != owner(),"Signer can't be the owner");
        signer = _signer;
        emit SetSigner(signer);
    }

    function setApprove(uint _blocknumber) internal{
        blockNumber = _blocknumber + block.number;
        emit SetApprove(blockNumber);
    }


    function timeLockGrantUpdate(uint blocknumber, uint nonce, bytes32 digest, bytes memory signature) external returns (bool){
        require(verify(blocknumber, owner(), nonce, digest, signature, signer), "Signed Message is not message sent");
        setApprove(blocknumber);
        return true;
    }

    function getBlockNumber() public view returns(uint){
        return blockNumber;
    }

}


 











