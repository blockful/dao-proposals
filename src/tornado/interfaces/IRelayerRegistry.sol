// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

/// @title Relayer Registry surface used by the Proposal 67 payload.
/// @dev The malicious payload returns spoofed governance()/staking() and gates
///      nullifyBalance() to the spoofed (attacker) governance.
interface IRelayerRegistry {
    function governance() external view returns (address);
    function staking() external view returns (address);
    function nullifyBalance(address relayer) external;
}
