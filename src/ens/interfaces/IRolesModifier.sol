// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

struct ConditionFlat {
    uint8 parent;
    uint8 paramType;
    uint8 operator;
    bytes compValue;
}

interface IRolesModifier {
    function setTransactionUnwrapper(address handler, bytes4 selector, address adapter) external;
    function revokeTarget(bytes32 roleKey, address targetAddress) external;
    function revokeFunction(bytes32 roleKey, address targetAddress, bytes4 selector) external;
    function scopeTarget(bytes32 roleKey, address targetAddress) external;
    function scopeFunction(
        bytes32 roleKey,
        address targetAddress,
        bytes4 selector,
        ConditionFlat[] calldata conditions,
        uint8 options
    ) external;
    function allowFunction(bytes32 roleKey, address targetAddress, bytes4 selector, uint8 options) external;
}
