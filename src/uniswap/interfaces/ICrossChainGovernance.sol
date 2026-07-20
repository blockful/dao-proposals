// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.25 <0.9.0;

interface ICrossDomainMessenger {
    event SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);

    function sendMessage(address target, bytes calldata message, uint32 minGasLimit) external;
}

interface ICrossChainAccount {
    function forward(address target, bytes calldata data) external;
}

interface IUniswapWormholeMessageSender {
    event MessageSent(bytes payload, address indexed messageReceiver);

    function sendMessage(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        address messageReceiver,
        uint16 receiverChainId
    )
        external
        payable;
}

interface IFxRoot {
    function sendMessageToChild(address receiver, bytes calldata data) external;
}
