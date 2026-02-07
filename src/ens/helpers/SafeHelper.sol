// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ISafe } from "@ens/interfaces/ISafe.sol";

/**
 * @title SafeHelper
 * @notice Shared helpers for building Gnosis Safe execTransaction calldata
 * @dev The ENS Endowment Safe (0x4F2083...64) is owned by the ENS Timelock
 *      (0xFe89cc7...b7 = wallet.ensdao.eth). The Timelock can execute
 *      transactions on the Safe via a pre-approved signature (r=owner, s=0, v=1).
 */
abstract contract SafeHelper {
    ISafe public constant endowmentSafe = ISafe(0x4F2083f5fBede34C2714aFfb3105539775f7FE64);

    /**
     * @notice Build a Gnosis Safe pre-approved signature for a given owner
     * @dev Format: r = padded owner address, s = 0, v = 1
     *      See https://docs.safe.global/advanced/smart-account-signatures#pre-validated-signatures
     * @param owner The Safe owner whose approval is being used
     * @return 65-byte pre-approved signature
     */
    function _buildPreApprovedSignature(address owner) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(uint256(uint160(owner))), // r = padded owner address
            bytes32(0),                       // s = 0
            uint8(1)                          // v = 1 (pre-approved)
        );
    }

    /**
     * @notice Encode a Safe execTransaction call (operation = Call, no gas params)
     * @param safe The Safe contract to call
     * @param to The target contract for the inner call
     * @param data The calldata for the inner call
     * @param owner The Safe owner providing the pre-approved signature
     * @return target The Safe address to call
     * @return calldata_ The encoded ISafe.execTransaction calldata
     */
    function _buildSafeExecCalldata(
        address safe,
        address to,
        bytes memory data,
        address owner
    ) internal pure returns (address target, bytes memory calldata_) {
        target = safe;
        calldata_ = abi.encodeWithSelector(
            ISafe.execTransaction.selector,
            to,                                   // to
            uint256(0),                           // value
            data,                                 // data
            uint8(0),                             // operation: Call
            uint256(0),                           // safeTxGas
            uint256(0),                           // baseGas
            uint256(0),                           // gasPrice
            address(0),                           // gasToken
            address(0),                           // refundReceiver
            _buildPreApprovedSignature(owner)     // signatures
        );
    }

    /**
     * @notice Encode a Safe execTransaction call with DelegateCall operation
     * @param safe The Safe contract to call
     * @param to The target contract for the inner delegatecall
     * @param data The calldata for the inner call
     * @param owner The Safe owner providing the pre-approved signature
     * @return target The Safe address to call
     * @return calldata_ The encoded ISafe.execTransaction calldata with DelegateCall
     */
    function _buildSafeExecDelegateCalldata(
        address safe,
        address to,
        bytes memory data,
        address owner
    ) internal pure returns (address target, bytes memory calldata_) {
        target = safe;
        calldata_ = abi.encodeWithSelector(
            ISafe.execTransaction.selector,
            to,                                   // to
            uint256(0),                           // value
            data,                                 // data
            uint8(1),                             // operation: DelegateCall
            uint256(0),                           // safeTxGas
            uint256(0),                           // baseGas
            uint256(0),                           // gasPrice
            address(0),                           // gasToken
            address(0),                           // refundReceiver
            _buildPreApprovedSignature(owner)     // signatures
        );
    }
}
