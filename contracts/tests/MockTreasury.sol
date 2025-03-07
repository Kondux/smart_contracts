// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract MockTreasury {
    // Simple treasury mock that can receive tokens
    event FundsReceived(address indexed from, uint256 amount);

    function receiveFunds(address from, uint256 amount) external payable {
        emit FundsReceived(from, amount);
    }

    // Function to retrieve ETH balance (for testing)
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    
}
