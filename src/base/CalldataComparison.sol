// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

/// @title CalldataComparison
/// @notice Shared logic for comparing generated calldata against proposalCalldata.json.
///         Inherit this in any DAO base class that supports JSON calldata verification.
abstract contract CalldataComparison is Test {
    /// @notice Compare generated calldata against JSON file (live format, no signatures)
    function _compareLiveCalldata(
        string memory jsonContent,
        address[] memory generatedTargets,
        uint256[] memory generatedValues,
        bytes[] memory generatedCalldatas
    ) internal {
        address[] memory jsonTargets = _parseJsonTargets(jsonContent);
        string[] memory jsonValues = _parseJsonValues(jsonContent);
        bytes[] memory jsonCalldatas = _parseJsonCalldatas(jsonContent);

        console2.log("JSON parsed successfully with", jsonTargets.length, "operations");

        assertEq(jsonTargets.length, generatedTargets.length, "Number of executable calls mismatch");

        for (uint256 i = 0; i < jsonTargets.length; i++) {
            assertEq(
                jsonTargets[i],
                generatedTargets[i],
                string(abi.encodePacked("Target mismatch at index ", vm.toString(i)))
            );
            assertEq(
                vm.parseUint(jsonValues[i]),
                generatedValues[i],
                string(abi.encodePacked("Value mismatch at index ", vm.toString(i)))
            );
            assertEq(
                jsonCalldatas[i],
                generatedCalldatas[i],
                string(abi.encodePacked("Calldata mismatch at index ", vm.toString(i)))
            );
        }
    }

    // ─── JSON Parsing (handles both array and single-element) ───────────

    function _decodeTargetsArray(string memory j) public pure returns (address[] memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].target"), (address[]));
    }

    function _decodeTargetSingle(string memory j) public pure returns (address) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].target"), (address));
    }

    function _parseJsonTargets(string memory j) internal returns (address[] memory result) {
        (bool ok, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._decodeTargetsArray.selector, j)
        );
        if (ok) return abi.decode(ret, (address[]));

        (bool ok2, bytes memory ret2) = address(this).call(abi.encodeWithSelector(this._decodeTargetSingle.selector, j));
        require(ok2, "JSON target decode failed");
        result = new address[](1);
        result[0] = abi.decode(ret2, (address));
    }

    function _decodeValuesArray(string memory j) public pure returns (string[] memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].value"), (string[]));
    }

    function _decodeValueSingle(string memory j) public pure returns (string memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].value"), (string));
    }

    function _parseJsonValues(string memory j) internal returns (string[] memory result) {
        (bool ok, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._decodeValuesArray.selector, j)
        );
        if (ok) return abi.decode(ret, (string[]));

        (bool ok2, bytes memory ret2) = address(this).call(abi.encodeWithSelector(this._decodeValueSingle.selector, j));
        require(ok2, "JSON value decode failed");
        result = new string[](1);
        result[0] = abi.decode(ret2, (string));
    }

    function _decodeCalldatasArray(string memory j) public pure returns (bytes[] memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].calldata"), (bytes[]));
    }

    function _decodeCalldataSingle(string memory j) public pure returns (bytes memory) {
        return abi.decode(vm.parseJson(j, ".executableCalls[*].calldata"), (bytes));
    }

    function _parseJsonCalldatas(string memory j) internal returns (bytes[] memory result) {
        (bool ok, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._decodeCalldatasArray.selector, j)
        );
        if (ok) return abi.decode(ret, (bytes[]));

        (bool ok2, bytes memory ret2) = address(this).call(abi.encodeWithSelector(this._decodeCalldataSingle.selector, j));
        require(ok2, "JSON calldata decode failed");
        result = new bytes[](1);
        result[0] = abi.decode(ret2, (bytes));
    }

    /// @notice Read proposal description from markdown file
    function _getDescriptionFromMarkdown(string memory _dirPath) internal returns (string memory) {
        return vm.readFile(string.concat(_dirPath, "/proposalDescription.md"));
    }
}
