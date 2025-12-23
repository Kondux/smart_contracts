// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title MockTreasury
 * @notice Minimal Treasury mock for MinterBundle tests
 */
contract MockTreasury {
    event DepositEther(uint256 amount);
    event FundsReceived(address indexed from, uint256 amount);

    function depositEther() external payable {
        emit DepositEther(msg.value);
    }

    function receiveFunds(address from, uint256 amount) external payable {
        emit FundsReceived(from, amount);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        emit DepositEther(msg.value);
    }
}
