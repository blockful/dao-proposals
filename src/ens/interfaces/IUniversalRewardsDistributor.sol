// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IUniversalRewardsDistributor {
    event Claimed(address indexed account, address indexed reward, uint256 amount);
    event OwnerSet(address indexed newOwner);
    event PendingRootRevoked(address indexed caller);
    event PendingRootSet(address indexed caller, bytes32 indexed newRoot, bytes32 indexed newIpfsHash);
    event RootSet(bytes32 indexed newRoot, bytes32 indexed newIpfsHash);
    event RootUpdaterSet(address indexed rootUpdater, bool active);
    event TimelockSet(uint256 newTimelock);

    function acceptRoot() external;
    function claim(address account, address reward, uint256 claimable, bytes32[] memory proof)
        external
        returns (uint256 amount);
    function claimed(address account, address reward) external view returns (uint256 amount);
    function ipfsHash() external view returns (bytes32);
    function isUpdater(address) external view returns (bool);
    function owner() external view returns (address);
    function pendingRoot() external view returns (bytes32 root, bytes32 ipfsHash, uint256 validAt);
    function revokePendingRoot() external;
    function root() external view returns (bytes32);
    function setOwner(address newOwner) external;
    function setRoot(bytes32 newRoot, bytes32 newIpfsHash) external;
    function setRootUpdater(address updater, bool active) external;
    function setTimelock(uint256 newTimelock) external;
    function submitRoot(bytes32 newRoot, bytes32 newIpfsHash) external;
    function timelock() external view returns (uint256);
}
