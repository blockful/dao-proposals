// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ILinearERC20Voting {
    error AlreadyVoted();
    error InvalidBasisNumerator();
    error InvalidProposal();
    error InvalidQuorumNumerator();
    error InvalidTokenAddress();
    error InvalidVote();
    error OnlyAzorius();
    error VotingEnded();

    event AzoriusSet(address indexed azoriusModule);
    event BasisNumeratorUpdated(uint256 basisNumerator);
    event Initialized(uint8 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProposalInitialized(uint32 proposalId, uint32 votingEndBlock);
    event QuorumNumeratorUpdated(uint256 quorumNumerator);
    event RequiredProposerWeightUpdated(uint256 requiredProposerWeight);
    event StrategySetUp(address indexed azoriusModule, address indexed owner);
    event Voted(address voter, uint32 proposalId, uint8 voteType, uint256 weight);
    event VotingPeriodUpdated(uint32 votingPeriod);

    function BASIS_DENOMINATOR() external view returns (uint256);
    function QUORUM_DENOMINATOR() external view returns (uint256);
    function azoriusModule() external view returns (address);
    function basisNumerator() external view returns (uint256);
    function getProposalVotes(uint32 _proposalId)
        external
        view
        returns (
            uint256 noVotes,
            uint256 yesVotes,
            uint256 abstainVotes,
            uint32 startBlock,
            uint32 endBlock,
            uint256 votingSupply
        );
    function getProposalVotingSupply(uint32 _proposalId) external view returns (uint256);
    function getVotingWeight(address _voter, uint32 _proposalId) external view returns (uint256);
    function governanceToken() external view returns (address);
    function hasVoted(uint32 _proposalId, address _address) external view returns (bool);
    function initializeProposal(bytes memory _data) external;
    function isPassed(uint32 _proposalId) external view returns (bool);
    function isProposer(address _address) external view returns (bool);
    function meetsBasis(uint256 _yesVotes, uint256 _noVotes) external view returns (bool);
    function meetsQuorum(uint256 _totalSupply, uint256 _yesVotes, uint256 _abstainVotes) external view returns (bool);
    function owner() external view returns (address);
    function quorumNumerator() external view returns (uint256);
    function quorumVotes(uint32 _proposalId) external view returns (uint256);
    function renounceOwnership() external;
    function requiredProposerWeight() external view returns (uint256);
    function setAzorius(address _azoriusModule) external;
    function setUp(bytes memory initializeParams) external;
    function transferOwnership(address newOwner) external;
    function updateBasisNumerator(uint256 _basisNumerator) external;
    function updateQuorumNumerator(uint256 _quorumNumerator) external;
    function updateRequiredProposerWeight(uint256 _requiredProposerWeight) external;
    function updateVotingPeriod(uint32 _votingPeriod) external;
    function vote(uint32 _proposalId, uint8 _voteType) external;
    function votingEndBlock(uint32 _proposalId) external view returns (uint32);
    function votingPeriod() external view returns (uint32);
}
