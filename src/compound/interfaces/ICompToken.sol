// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface ICompToken {
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function delegates(address account) external view returns (address);
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}
