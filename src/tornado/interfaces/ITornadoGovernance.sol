// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @title Tornado Cash custom governor interface (stake-to-vote).
/// @dev Voting power is `lockedBalance`; votes are boolean; proposals are contracts
///      executed via delegatecall `executeProposal()`.
interface ITornadoGovernance {
    function lockWithApproval(uint256 amount) external;
    function unlock(uint256 amount) external;
    function propose(address target, string calldata description) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function execute(uint256 proposalId) external payable;
    function delegate(address to) external;

    function state(uint256 proposalId) external view returns (uint8);
    function lockedBalance(address account) external view returns (uint256);
    function delegatedTo(address account) external view returns (address);
    function proposalCount() external view returns (uint256);

    // solhint-disable func-name-mixedcase
    function QUORUM_VOTES() external view returns (uint256);
    function PROPOSAL_THRESHOLD() external view returns (uint256);
    function VOTING_DELAY() external view returns (uint256);
    function VOTING_PERIOD() external view returns (uint256);
    function EXECUTION_DELAY() external view returns (uint256);
    // solhint-enable func-name-mixedcase
}
