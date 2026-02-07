// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IENSRoot} from "@ens/interfaces/IENSRoot.sol";
import {IENSRegistryWithFallback} from "@ens/interfaces/IENSRegistryWithFallback.sol";
import {Ownable} from "./vendor/oz-v4/Ownable.sol";
import {ERC165} from "./vendor/oz-v4/ERC165.sol";

/// @title RootSecurityController
/// @notice Break-glass controller for ENS root operations.
/// @dev Ownable contract that can disable a TLD and clear its resolver in
///      emergencies.
contract RootSecurityController is Ownable, ERC165 {
    bytes32 private constant ROOT_NODE = bytes32(0);

    /// @notice The root contract.
    IENSRoot public root;
    /// @notice The ENS registry.
    IENSRegistryWithFallback public ens;

    /// @param _root The root contract to manage.
    constructor(IENSRoot _root) {
        root = _root;
        ens = IENSRegistryWithFallback(_root.ens());
    }

    /// @notice Takes ownership of a TLD and clears its resolver.
    /// @param label The labelhash of the TLD to disable.
    function disableTLD(bytes32 label) external onlyOwner {
        root.setSubnodeOwner(label, address(this));
        ens.setResolver(keccak256(abi.encodePacked(ROOT_NODE, label)), address(0));
    }
}
