// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface IStETH {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}
