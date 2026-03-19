// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "@forge-std/src/interfaces/IERC20.sol";

interface ICowSwapOrderSigner {
    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        bytes32 kind;
        bool partiallyFillable;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    function signOrder(Data memory order, uint32 validDuration, uint256 feeAmount) external;
}
