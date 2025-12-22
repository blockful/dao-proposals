// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @title UNI Vesting Interface
/// @notice Interface for the UNI Vesting contract that handles quarterly UNI distributions
interface IUNIVesting {
    error CannotUpdateAmount();
    error InsufficientAllowance();
    error NoChangeUpdate();
    error NotAuthorized();
    error OnlyQuarterly();

    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event RecipientUpdated(address recipient);
    event VestingAmountUpdated(uint256 amount);
    event Withdrawn(address indexed recipient, uint256 amount, uint48 quartersPaid);

    function UNI() external view returns (address);
    function lastUnlockTimestamp() external view returns (uint48);
    function owner() external view returns (address);
    function quarterlyVestingAmount() external view returns (uint256);
    function quartersPassed() external view returns (uint48);
    function recipient() external view returns (address);
    function transferOwnership(address newOwner) external;
    function updateRecipient(address _recipient) external;
    function updateVestingAmount(uint256 amount) external;
    function withdraw() external;
}

