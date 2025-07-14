// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library ProposalStateCompound {
    type ProposalState is uint8;
}

interface IGovernor {
    struct ProposalGuardian {
        address account;
        uint96 expiration;
    }

    error CheckpointUnorderedInsertion();
    error FailedCall();
    error GovernorAlreadyCastVote(address voter);
    error GovernorAlreadyQueuedProposal(uint256 proposalId);
    error GovernorDisabledDeposit();
    error GovernorExceedRemainingWeight(address voter, uint256 usedVotes, uint256 remainingWeight);
    error GovernorInsufficientProposerVotes(address proposer, uint256 votes, uint256 threshold);
    error GovernorInvalidProposalLength(uint256 targets, uint256 calldatas, uint256 values);
    error GovernorInvalidSignature(address voter);
    error GovernorInvalidVoteParams();
    error GovernorInvalidVoteType();
    error GovernorInvalidVotingPeriod(uint256 votingPeriod);
    error GovernorNonexistentProposal(uint256 proposalId);
    error GovernorNotQueuedProposal(uint256 proposalId);
    error GovernorOnlyExecutor(address account);
    error GovernorOnlyProposer(address account);
    error GovernorQueueNotImplemented();
    error GovernorRestrictedProposer(address proposer);
    error GovernorUnexpectedProposalState(uint256 proposalId, uint8 current, bytes32 expectedStates);
    error InsufficientBalance(uint256 balance, uint256 needed);
    error InvalidAccountNonce(address account, uint256 currentNonce);
    error InvalidInitialization();
    error NotInitializing();
    error ProposalIdAlreadySet();
    error ProposerActiveProposal(address proposer, uint256 proposalId, uint8 state);
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);
    error Unauthorized(bytes32 reason, address caller);

    event EIP712DomainChanged();
    event Initialized(uint64 version);
    event LateQuorumVoteExtensionSet(uint64 oldVoteExtension, uint64 newVoteExtension);
    event ProposalCanceled(uint256 proposalId);
    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 voteStart,
        uint256 voteEnd,
        string description
    );
    event ProposalExecuted(uint256 proposalId);
    event ProposalExtended(uint256 indexed proposalId, uint64 extendedDeadline);
    event ProposalGuardianSet(
        address oldProposalGuardian,
        uint96 oldProposalGuardianExpiry,
        address newProposalGuardian,
        uint96 newProposalGuardianExpiry
    );
    event ProposalQueued(uint256 proposalId, uint256 etaSeconds);
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);
    event TimelockChange(address oldTimelock, address newTimelock);
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event VoteCastWithParams(
        address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params
    );
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);
    event WhitelistAccountExpirationSet(address account, uint256 expiration);
    event WhitelistGuardianSet(address oldGuardian, address newGuardian);

    receive() external payable;

    function BALLOT_TYPEHASH() external view returns (bytes32);
    function CLOCK_MODE() external view returns (string memory);
    function COUNTING_MODE() external pure returns (string memory);
    function EXTENDED_BALLOT_TYPEHASH() external view returns (bytes32);
    function __acceptAdmin() external;
    function cancel(uint256 _proposalId) external;
    function cancel(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) external returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function castVoteBySig(uint256 proposalId, uint8 support, address voter, bytes memory signature)
        external
        returns (uint256);
    function castVoteWithReason(uint256 proposalId, uint8 support, string memory reason) external returns (uint256);
    function castVoteWithReasonAndParams(uint256 proposalId, uint8 support, string memory reason, bytes memory params)
        external
        returns (uint256);
    function castVoteWithReasonAndParamsBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        string memory reason,
        bytes memory params,
        bytes memory signature
    ) external returns (uint256);
    function clock() external view returns (uint48);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external payable returns (uint256);
    function execute(uint256 _proposalId) external payable;
    function getNextProposalId() external view returns (uint256);
    function getVotes(address account, uint256 timepoint) external view returns (uint256);
    function getVotesWithParams(address account, uint256 timepoint, bytes memory params)
        external
        view
        returns (uint256);
    function hasVoted(uint256 proposalId, address account) external view returns (bool);
    function hashProposal(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) external returns (uint256);
    function initialize(
        uint48 _initialVotingDelay,
        uint32 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        address _compAddress,
        uint256 _quorumVotes,
        address _timelockAddress,
        uint48 _initialVoteExtension,
        address _whitelistGuardian,
        ProposalGuardian memory _proposalGuardian
    ) external;
    function isWhitelisted(address _account) external view returns (bool);
    function lateQuorumVoteExtension() external view returns (uint48);
    function latestProposalIds(address proposer) external view returns (uint256 latestProposalId);
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        external
        returns (bytes4);
    function onERC1155Received(address, address, uint256, uint256, bytes memory) external returns (bytes4);
    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);
    function proposalCount() external view returns (uint256);
    function proposalDeadline(uint256 _proposalId) external view returns (uint256);
    function proposalDetails(uint256 _proposalId)
        external
        view
        returns (address[] memory, uint256[] memory, bytes[] memory, bytes32);
    function proposalEta(uint256 proposalId) external view returns (uint256);
    function proposalGuardian() external view returns (address account, uint96 expiration);
    function proposalNeedsQueuing(uint256 _proposalId) external view returns (bool);
    function proposalProposer(uint256 proposalId) external view returns (address);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function proposalVotes(uint256 proposalId)
        external
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes);
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external returns (uint256);
    function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        external
        returns (uint256);
    function queue(uint256 _proposalId) external;
    function quorum(uint256 _voteStart) external view returns (uint256);
    function relay(address target, uint256 value, bytes memory data) external payable;
    function setLateQuorumVoteExtension(uint48 newVoteExtension) external;
    function setNextProposalId() external;
    function setProposalGuardian(ProposalGuardian memory _newProposalGuardian) external;
    function setProposalThreshold(uint256 newProposalThreshold) external;
    function setQuorum(uint256 _amount) external;
    function setVotingDelay(uint48 newVotingDelay) external;
    function setVotingPeriod(uint32 newVotingPeriod) external;
    function setWhitelistAccountExpiration(address _account, uint256 _expiration) external;
    function setWhitelistGuardian(address _newWhitelistGuardian) external;
    function state(uint256 _proposalId) external view returns (uint8);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function timelock() external view returns (address);
    function token() external view returns (address);
    function updateTimelock(address newTimelock) external;
    function usedVotes(uint256 proposalId, address account) external view returns (uint256);
    function version() external view returns (string memory);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function whitelistAccountExpirations(address account) external view returns (uint256 timestamp);
    function whitelistGuardian() external view returns (address);
}
