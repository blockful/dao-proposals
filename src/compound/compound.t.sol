// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";
import { ICompoundGovernor } from "@compound/interfaces/ICompoundGovernor.sol";
import { ICompoundTimelock } from "@compound/interfaces/ICompoundTimelock.sol";
import { ICompToken } from "@compound/interfaces/ICompToken.sol";

/// @notice Shared mainnet addresses and lifecycle helper for Compound Governor Bravo proposal reviews.
abstract contract Compound_Governance is Test, CalldataComparison {
    ICompoundGovernor internal constant GOVERNOR = ICompoundGovernor(0x309a862bbC1A00e45506cB8A802D1ff10004c8C0);
    ICompoundTimelock internal constant TIMELOCK = ICompoundTimelock(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925);
    ICompToken internal constant COMP = ICompToken(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    function _executeLiveProposal(uint256 proposalId, uint256 voteStart, uint256 voteEnd, address voter) internal {
        vm.mockCall(
            address(COMP),
            abi.encodeWithSelector(ICompToken.getPriorVotes.selector, voter, voteStart),
            abi.encode(uint96(1_000_000 ether))
        );
        vm.prank(voter);
        GOVERNOR.castVote(proposalId, 1);
        vm.roll(voteEnd + 1);
        assertEq(GOVERNOR.state(proposalId), 4, "proposal did not succeed");

        GOVERNOR.queue(proposalId);
        vm.warp(block.timestamp + TIMELOCK.delay() + 1);
        GOVERNOR.execute(proposalId);
        assertEq(GOVERNOR.state(proposalId), 7, "proposal was not executed");
    }
}
