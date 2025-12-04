// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library IGhoToken {
    struct Facilitator {
        uint128 bucketCapacity;
        uint128 bucketLevel;
        string label;
    }
}

interface IGHO {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event FacilitatorAdded(address indexed facilitatorAddress, bytes32 indexed label, uint256 bucketCapacity);
    event FacilitatorBucketCapacityUpdated(
        address indexed facilitatorAddress, uint256 oldCapacity, uint256 newCapacity
    );
    event FacilitatorBucketLevelUpdated(address indexed facilitatorAddress, uint256 oldLevel, uint256 newLevel);
    event FacilitatorRemoved(address indexed facilitatorAddress);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function BUCKET_MANAGER_ROLE() external view returns (bytes32);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function FACILITATOR_MANAGER_ROLE() external view returns (bytes32);
    function PERMIT_TYPEHASH() external view returns (bytes32);
    function addFacilitator(address facilitatorAddress, string memory facilitatorLabel, uint128 bucketCapacity)
        external;
    function allowance(address, address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function burn(uint256 amount) external;
    function decimals() external view returns (uint8);
    function getFacilitator(address facilitator) external view returns (IGhoToken.Facilitator memory);
    function getFacilitatorBucket(address facilitator) external view returns (uint256, uint256);
    function getFacilitatorsList() external view returns (address[] memory);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function mint(address account, uint256 amount) external;
    function name() external view returns (string memory);
    function nonces(address) external view returns (uint256);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function removeFacilitator(address facilitatorAddress) external;
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function setFacilitatorBucketCapacity(address facilitator, uint128 newCapacity) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
