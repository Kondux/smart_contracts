// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Interface for Uniswap V2 Pair
interface IUniswapV2Pair {
    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );

    function token0() external view returns (address);
    function token1() external view returns (address);
}