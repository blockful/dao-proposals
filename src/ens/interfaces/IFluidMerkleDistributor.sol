// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library Structs {
    struct MerkleCycle {
        bytes32 merkleRoot;
        bytes32 merkleContentHash;
        uint40 cycle;
        uint40 timestamp;
        uint40 publishBlock;
        uint40 startBlock;
        uint40 endBlock;
    }
}

interface IFluidMerkleDistributor {
    error InvalidCycle();
    error InvalidParams();
    error InvalidProof();
    error MsgSenderNotRecipient();
    error NothingToClaim();
    error Unauthorized();

    event LogClaimed(
        address user,
        uint256 amount,
        uint256 cycle,
        uint8 positionType,
        bytes32 positionId,
        uint256 timestamp,
        uint256 blockNumber
    );
    event LogRootProposed(uint256 cycle, bytes32 root, bytes32 contentHash, uint256 timestamp, uint256 blockNumber);
    event LogRootUpdated(uint256 cycle, bytes32 root, bytes32 contentHash, uint256 timestamp, uint256 blockNumber);
    event LogUpdateApprover(address approver, bool isApprover);
    event LogUpdateProposer(address proposer, bool isProposer);
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event Paused(address account);
    event Unpaused(address account);

    function TOKEN() external view returns (address);
    function approveRoot(bytes32 root_, bytes32 contentHash_, uint40 cycle_, uint40 startBlock_, uint40 endBlock_)
        external;
    function claim(
        address recipient_,
        uint256 cumulativeAmount_,
        uint8 positionType_,
        bytes32 positionId_,
        uint256 cycle_,
        bytes32[] memory merkleProof_,
        bytes memory metadata_
    ) external;
    function claimed(address, bytes32) external view returns (uint256);
    function currentMerkleCycle() external view returns (Structs.MerkleCycle memory);
    function encodeClaim(
        address recipient_,
        uint256 cumulativeAmount_,
        uint8 positionType_,
        bytes32 positionId_,
        uint256 cycle_,
        bytes memory metadata_
    ) external pure returns (bytes memory encoded_, bytes32 hash_);
    function hasPendingRoot() external view returns (bool);
    function isApprover(address approver_) external view returns (bool);
    function isProposer(address proposer_) external view returns (bool);
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pendingMerkleCycle() external view returns (Structs.MerkleCycle memory);
    function previousMerkleRoot() external view returns (bytes32);
    function proposeRoot(bytes32 root_, bytes32 contentHash_, uint40 cycle_, uint40 startBlock_, uint40 endBlock_)
        external;
    function spell(address[] memory targets_, bytes[] memory calldatas_) external;
    function transferOwnership(address newOwner) external;
    function unpause() external;
    function updateApprover(address approver_, bool isApprover_) external;
    function updateProposer(address proposer_, bool isProposer_) external;
}
