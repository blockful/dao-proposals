// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

interface IMetadataService {
    function uri(uint256) external view returns (string memory);
}
