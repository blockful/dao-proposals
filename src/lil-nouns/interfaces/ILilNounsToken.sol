// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface ILilNounsToken {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}
