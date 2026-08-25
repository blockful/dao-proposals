// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface INounsListingManager {
    error NotTreasury();

    function FWA() external view returns (address);
    function MIN_BACKING() external view returns (uint256);
    function NOUNS() external view returns (address);
    function REWARDS() external view returns (address);
    function TREASURY() external view returns (address);
    function operator() external view returns (address);
    function pull(uint256[] calldata tokenIds) external;
}
