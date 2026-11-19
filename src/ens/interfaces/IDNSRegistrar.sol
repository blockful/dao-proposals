// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IDNSSEC } from "./IDNSSEC.sol";

interface IDNSRegistrar {
    error StaleProof(bytes name, uint16 typeCovered, uint32 lastTime, uint32 time);
    error PreconditionNotMet();

    function ens() external view returns (address);
    function oracle() external view returns (address);
    function resolver() external view returns (address);
    function suffixes() external view returns (address);
    function previousRegistrar() external view returns (address);
    function wasRegistrar(address registrar) external view returns (bool);
    function inceptions(bytes32 node) external view returns (uint32);
    function getInception(bytes calldata name, uint16 typeCovered) external view returns (uint32);

    function enableNode(bytes memory domain) external returns (bytes32 node);
    function proveAndClaim(bytes memory name, IDNSSEC.RRSetWithSignature[] memory input) external;
}

interface IDNSRegistrar2021 {
    function oracle() external view returns (address);
    function suffixes() external view returns (address);
    function claim(bytes memory name, bytes memory proof) external;
}
