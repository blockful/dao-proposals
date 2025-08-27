// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library AutoWrapper {
    struct WrapSchedule {
        address user;
        address superToken;
        address strategy;
        address liquidityToken;
        uint64 expiry;
        uint64 lowerLimit;
        uint64 upperLimit;
    }
}

interface IAutoWrapper {
    error InsufficientLimits(uint64 limitGiven, uint64 minLimit);
    error InvalidExpirationTime(uint64 expirationTimeGiven, uint256 timeNow);
    error InvalidStrategy(address strategy);
    error UnauthorizedCaller(address caller, address expectedCaller);
    error UnsupportedSuperToken(address superToken);
    error WrapNotRequired(bytes32 index);
    error WrongLimits(uint64 lowerLimit, uint64 upperLimit);
    error ZeroAddress();

    event AddedApprovedStrategy(address indexed strategy);
    event LimitsChanged(uint64 lowerLimit, uint64 upperLimit);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RemovedApprovedStrategy(address indexed strategy);
    event WrapExecuted(bytes32 indexed id, uint256 wrapAmount);
    event WrapScheduleCreated(
        bytes32 indexed id,
        address indexed user,
        address indexed superToken,
        address strategy,
        address liquidityToken,
        uint256 expiry,
        uint256 lowerLimit,
        uint256 upperLimit
    );
    event WrapScheduleDeleted(
        bytes32 indexed id, address indexed user, address indexed superToken, address strategy, address liquidityToken
    );

    function addApprovedStrategy(address strategy) external;
    function approvedStrategies(address) external view returns (bool);
    function cfaV1() external view returns (address);
    function checkWrap(address user, address superToken, address liquidityToken) external view returns (uint256);
    function checkWrapByIndex(bytes32 index) external view returns (uint256 amount);
    function createWrapSchedule(
        address superToken,
        address strategy,
        address liquidityToken,
        uint64 expiry,
        uint64 lowerLimit,
        uint64 upperLimit
    ) external;
    function deleteWrapSchedule(address user, address superToken, address liquidityToken) external;
    function deleteWrapScheduleByIndex(bytes32 index) external;
    function executeWrap(address user, address superToken, address liquidityToken) external;
    function executeWrapByIndex(bytes32 index) external;
    function getWrapSchedule(address user, address superToken, address liquidityToken)
        external
        view
        returns (AutoWrapper.WrapSchedule memory);
    function getWrapScheduleByIndex(bytes32 index) external view returns (AutoWrapper.WrapSchedule memory);
    function getWrapScheduleIndex(address user, address superToken, address liquidityToken)
        external
        pure
        returns (bytes32);
    function minLower() external view returns (uint64);
    function minUpper() external view returns (uint64);
    function owner() external view returns (address);
    function removeApprovedStrategy(address strategy) external;
    function renounceOwnership() external;
    function setLimits(uint64 lowerLimit, uint64 upperLimit) external;
    function transferOwnership(address newOwner) external;
}
