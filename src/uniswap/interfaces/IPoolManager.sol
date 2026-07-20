// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

interface IPoolManager {
    function protocolFeeController() external view returns (address);

    function setProtocolFeeController(address controller) external;
}
