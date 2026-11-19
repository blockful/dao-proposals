// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface IOffchainDNSResolver {
    function ens() external view returns (address);
    function oracle() external view returns (address);
    function gatewayURL() external view returns (string memory);

    function resolveCallback(bytes calldata response, bytes calldata extraData) external view returns (bytes memory);
}

interface IPublicSuffixList {
    function isPublicSuffix(bytes calldata name) external view returns (bool);
}
