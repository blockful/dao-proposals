// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";
import { LilNounsConstants } from "@lil-nouns/Constants.sol";
import { ILilNounsDAO } from "@lil-nouns/interfaces/ILilNounsDAO.sol";
import { ILilNounsTimelock } from "@lil-nouns/interfaces/ILilNounsTimelock.sol";
import { ILilNounsToken } from "@lil-nouns/interfaces/ILilNounsToken.sol";

abstract contract LilNouns_Governance is CalldataComparison {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed,
        Vetoed,
        ObjectionPeriod,
        Updatable
    }

    ILilNounsDAO internal constant GOVERNOR = ILilNounsDAO(LilNounsConstants.GOVERNOR);
    ILilNounsTimelock internal constant TIMELOCK = ILilNounsTimelock(LilNounsConstants.TIMELOCK);
    ILilNounsToken internal constant LIL_NOUNS = ILilNounsToken(LilNounsConstants.TOKEN);

    uint256 public proposalId;
    address[] public targets;
    uint256[] public values;
    string[] public signatures;
    bytes[] public calldatas;

    function setUp() public virtual {
        _selectFork();
        vm.label(LilNounsConstants.GOVERNOR, "LilNounsDAO");
        vm.label(LilNounsConstants.TIMELOCK, "LilNounsTimelock");
        vm.label(LilNounsConstants.TOKEN, "LilNounsToken");
    }

    function test_proposal() public {
        proposalId = _proposalId();
        (targets, values, signatures, calldatas) = _generateCallData();

        _verifyManualCalldataAgainstChain();
        _verifyManualCalldataAgainstJson();
        _beforeProposal();

        assertEq(GOVERNOR.state(proposalId), uint8(ProposalState.Pending), "proposal not Pending");
        assertEq(GOVERNOR.timelock(), LilNounsConstants.TIMELOCK, "unexpected execution timelock");

        _rollAndWarp(_startBlock() + 1);
        assertEq(GOVERNOR.state(proposalId), uint8(ProposalState.Active), "proposal not Active");

        address[] memory voters = _voters();
        uint256 totalVotes;
        for (uint256 i = 0; i < voters.length; ++i) {
            totalVotes += LIL_NOUNS.getPriorVotes(voters[i], _startBlock());
        }
        assertGe(totalVotes, _quorumVotes(), "configured voters do not meet quorum");

        for (uint256 i = 0; i < voters.length; ++i) {
            vm.prank(voters[i]);
            GOVERNOR.castVote(proposalId, 1);
        }

        _rollAndWarp(_endBlock() + 1);
        assertEq(GOVERNOR.state(proposalId), uint8(ProposalState.Succeeded), "proposal not Succeeded");

        GOVERNOR.queue(proposalId);
        assertEq(GOVERNOR.state(proposalId), uint8(ProposalState.Queued), "proposal not Queued");

        uint256 delay = TIMELOCK.delay();
        vm.warp(block.timestamp + delay + 1);
        vm.roll(block.number + (delay / 12) + 1);
        _beforeExecution();
        GOVERNOR.execute(proposalId);

        assertEq(GOVERNOR.state(proposalId), uint8(ProposalState.Executed), "proposal not Executed");
        _afterExecution();
    }

    function _verifyManualCalldataAgainstChain() internal view {
        (
            address[] memory chainTargets,
            uint256[] memory chainValues,
            string[] memory chainSignatures,
            bytes[] memory chainCalldatas
        ) = GOVERNOR.getActions(proposalId);
        assertEq(chainTargets.length, targets.length, "on-chain action count mismatch");
        for (uint256 i = 0; i < targets.length; ++i) {
            assertEq(chainTargets[i], targets[i], "on-chain target mismatch");
            assertEq(chainValues[i], values[i], "on-chain value mismatch");
            assertEq(chainSignatures[i], signatures[i], "on-chain signature mismatch");
            assertEq(chainCalldatas[i], calldatas[i], "on-chain calldata mismatch");
        }
    }

    function _verifyManualCalldataAgainstJson() internal {
        string memory jsonContent = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        for (uint256 i = 0; i < signatures.length; ++i) {
            string memory root = string.concat(".executableCalls[", vm.toString(i), "]");
            assertEq(
                vm.parseAddress(vm.parseJsonString(jsonContent, string.concat(root, ".target"))),
                targets[i],
                "JSON target mismatch"
            );
            assertEq(
                vm.parseUint(vm.parseJsonString(jsonContent, string.concat(root, ".value"))),
                values[i],
                "JSON value mismatch"
            );
            assertEq(
                vm.parseBytes(vm.parseJsonString(jsonContent, string.concat(root, ".calldata"))),
                calldatas[i],
                "JSON calldata mismatch"
            );
            assertEq(
                vm.parseJsonString(jsonContent, string.concat(root, ".signature")),
                signatures[i],
                "JSON signature mismatch"
            );
        }
    }

    function _rollAndWarp(uint256 targetBlock) internal {
        uint256 blockDelta = targetBlock - block.number;
        vm.roll(targetBlock);
        vm.warp(block.timestamp + blockDelta * 12);
    }

    function _voters() internal pure returns (address[] memory voters) {
        voters = new address[](1);
        voters[0] = 0x0BC3807Ec262cB779b38D65b38158acC3bfedE10;
    }

    function _selectFork() public virtual;
    function _proposalId() internal pure virtual returns (uint256);
    function _startBlock() internal pure virtual returns (uint256);
    function _endBlock() internal pure virtual returns (uint256);
    function _quorumVotes() internal pure virtual returns (uint256);
    function _generateCallData()
        internal
        pure
        virtual
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory);
    function _beforeProposal() internal virtual;
    function _beforeExecution() internal virtual;
    function _afterExecution() internal virtual;
}
