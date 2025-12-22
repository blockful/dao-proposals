// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

/// @title Ethereum Attestation Service Interface
/// @notice Interface for EAS (AgreementAnchor) used in the UNIfication proposal
interface IEAS {
    struct AttestationRequestData {
        address recipient;
        uint64 expirationTime;
        bool revocable;
        bytes32 refUID;
        bytes data;
        uint256 value;
    }

    struct AttestationRequest {
        bytes32 schema;
        AttestationRequestData data;
    }

    struct Attestation {
        bytes32 uid;
        bytes32 schema;
        uint64 time;
        uint64 expirationTime;
        uint64 revocationTime;
        bytes32 refUID;
        address recipient;
        address attester;
        bool revocable;
        bytes data;
    }

    event Attested(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schema);
    event Revoked(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schema);
    event Timestamped(bytes32 indexed data, uint64 indexed timestamp);

    function attest(AttestationRequest calldata request) external payable returns (bytes32);
    function getAttestation(bytes32 uid) external view returns (Attestation memory);
    function isAttestationValid(bytes32 uid) external view returns (bool);
    function getSchemaRegistry() external view returns (address);
    function getRevokeOffchain(address revoker, bytes32 data) external view returns (uint64);
    function getTimestamp(bytes32 data) external view returns (uint64);
}

