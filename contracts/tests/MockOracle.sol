// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import "../KonduxTieredPayments.sol"; // For IUsageOracle interface

contract UsageOracleMock is IUsageOracle {
    mapping(address => mapping(address => uint256)) public usageByProviderUser;

    
    function setUsage(address provider, address user, uint256 amount) external {
        usageByProviderUser[provider][user] = amount;
    }
    
    function getUsage(address provider, address user) external view override returns (uint256) {
        return usageByProviderUser[provider][user]; 
    }
}