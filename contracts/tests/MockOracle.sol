// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import "../KonduxTieredPayments.sol"; // For IUsageOracle interface

contract UsageOracleMock is IUsageOracle {
    mapping(address =>  uint256) public usageByUser;

    
    function setUsage(address user, uint256 amount) external {
        usageByUser[user] = amount;
    }
    
    function getUsage(address user) external view override returns (uint256) {
        return usageByUser[user];
    }
    
    function resetUsage(address user) external {
        usageByUser[user] = 0;
    }
}