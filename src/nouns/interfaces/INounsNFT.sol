// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

interface INounsNFT {
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
}
