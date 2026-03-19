// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IAnnotationRegistry {
    function post(string calldata schema, string calldata data) external;
}
