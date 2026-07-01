// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @notice Minimal interface for the ENS Security Council (Term 2) — blockful/security-council-ens.
interface ISecurityCouncil {
    function owner() external view returns (address);

    function timelock() external view returns (address);

    function expiration() external view returns (uint256);

    function veto(bytes32 proposalId) external;

    function extend(uint256 newExpiration) external;

    function renounceTimelockRoleByExpiration() external;
}
