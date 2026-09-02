// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface IERC20Balance {
    function balanceOf(address account) external view returns (uint256);
}
