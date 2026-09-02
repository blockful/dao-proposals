// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface IStream {
    error CallerNotPayerOrRecipient();
    error StreamNotActive();

    function cancel() external;
    function payer() external view returns (address);
    function recipient() external view returns (address);
    function recipientActiveBalance() external view returns (uint256);
    function recipientBalance() external view returns (uint256);
    function recipientCancelBalance() external view returns (uint256);
    function recoverTokens(address to) external returns (uint256 tokensToWithdraw);
    function remainingBalance() external view returns (uint256);
    function startTime() external view returns (uint256);
    function stopTime() external view returns (uint256);
    function token() external view returns (address);
    function tokenAmount() external view returns (uint256);
}
