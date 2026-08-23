// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface INounsDAO {
    function castVote(uint256 proposalId, uint8 support) external;
    function execute(uint256 proposalId) external;
    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );
    function queue(uint256 proposalId) external;
    function state(uint256 proposalId) external view returns (uint8);
    function timelock() external view returns (address);
}
