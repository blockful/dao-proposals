// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface IAnnotationRegistry {
    function post(string calldata schema, string calldata data) external;
}
