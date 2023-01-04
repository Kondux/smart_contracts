//SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

interface IStaking {
    function getStakedAmount(address _user) external view returns (uint256);
}