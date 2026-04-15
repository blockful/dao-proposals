// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { IMultiSend } from "@ens/interfaces/IMultiSend.sol";
import { SafeHelper } from "@ens/helpers/SafeHelper.sol";

/// @title MultiSendHelper
/// @notice Helpers for building MultiSend transactions executed through the Endowment Safe.
/// @dev MultiSend packs multiple transactions into a single delegatecall.
///      Format per tx: uint8 operation | address to | uint256 value | uint256 dataLength | bytes data
abstract contract MultiSendHelper is SafeHelper {
    IMultiSend internal constant multiSend = IMultiSend(0x40A2aCCbd92BCA938b02010E17A5b8929b49130D);

    /// @notice Pack a Call transaction for MultiSend (operation=0, value=0)
    function _packCall(address to, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), to, uint256(0), uint256(data.length), data);
    }

    /// @notice Pack a DelegateCall transaction for MultiSend (operation=1, value=0)
    function _packDelegateCall(address to, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(1), to, uint256(0), uint256(data.length), data);
    }

    /// @notice Pack a Call transaction with ETH value for MultiSend
    function _packCallWithValue(address to, uint256 value, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(0), to, value, uint256(data.length), data);
    }

    /// @notice Build full Safe execTransaction calldata for a MultiSend batch
    /// @param packedTransactions Concatenated result of _packCall/_packDelegateCall calls
    /// @param safe The Safe to execute through
    /// @param owner The Safe owner providing pre-approved signature (typically the timelock)
    /// @return target The Safe address
    /// @return calldata_ The encoded execTransaction calldata
    function _buildSafeMultiSendCalldata(
        bytes memory packedTransactions,
        address safe,
        address owner
    )
        internal
        pure
        returns (address target, bytes memory calldata_)
    {
        bytes memory multiSendData = abi.encodeWithSelector(IMultiSend.multiSend.selector, packedTransactions);
        return _buildSafeExecDelegateCalldata(safe, address(multiSend), multiSendData, owner);
    }
}
