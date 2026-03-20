// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface IMultiSend {
    function multiSend(bytes calldata transactions) external;
}
