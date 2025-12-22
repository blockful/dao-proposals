// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @title TokenJar Interface
/// @notice Interface for the TokenJar contract that collects protocol fees
interface ITokenJar {
    type Currency is address;

    error Unauthorized();

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    receive() external payable;

    function owner() external view returns (address);
    function release(Currency[] memory assets, address recipient) external;
    function releaser() external view returns (address);
    function setReleaser(address _releaser) external;
    function transferOwnership(address newOwner) external;
}

