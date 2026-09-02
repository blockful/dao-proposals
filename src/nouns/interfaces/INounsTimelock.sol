// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface INounsTimelock {
    function delay() external view returns (uint256);
}
