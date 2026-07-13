// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

interface ISafe {
    function execTransaction(
        address,
        uint256,
        bytes memory,
        uint8,
        uint256,
        uint256,
        uint256,
        address,
        address,
        bytes memory
    )
        external;

    function getOwners() external view returns (address[] memory);

    function getThreshold() external view returns (uint256);

    function getModulesPaginated(
        address start,
        uint256 pageSize
    )
        external
        view
        returns (address[] memory array, address next);

    function VERSION() external view returns (string memory);
}
