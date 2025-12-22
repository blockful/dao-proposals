// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

interface IV2FeeToSetter {
    function setFeeToSetter(address _feeToSetter) external;
    function setFeeTo(address _feeTo) external;
}

