// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

interface IV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function setFeeTo(address _feeTo) external;
    function setFeeToSetter(address _feeToSetter) external;
}

