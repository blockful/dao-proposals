// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface ICompoundGovernor {
    function state(uint256 proposalId) external view returns (uint8);
    function proposalDetails(uint256 proposalId)
        external
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
}
