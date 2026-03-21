// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface ISparkRewards {
    function claim(
        uint256 rewardId,
        address to,
        address reward,
        uint256 amount,
        bytes32 root,
        bytes32[] calldata proof
    ) external;
}
