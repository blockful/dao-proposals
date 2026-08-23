// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";
import { NounsConstants } from "@nouns/Constants.sol";
import { INounsDAO } from "@nouns/interfaces/INounsDAO.sol";
import { INounsTimelock } from "@nouns/interfaces/INounsTimelock.sol";
import { INounsToken } from "@nouns/interfaces/INounsToken.sol";

abstract contract Nouns_Governance is CalldataComparison {
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

    INounsDAO internal constant GOVERNOR = INounsDAO(NounsConstants.GOVERNOR);
    INounsTimelock internal constant TIMELOCK = INounsTimelock(NounsConstants.TIMELOCK);
    INounsToken internal constant NOUNS = INounsToken(NounsConstants.TOKEN);

    uint256 public proposalId;
    address[] public targets;
    uint256[] public values;
    string[] public signatures;
    bytes[] public calldatas;

    function setUp() public virtual {
        _selectFork();
        vm.label(NounsConstants.GOVERNOR, "NounsDAO");
        vm.label(NounsConstants.TIMELOCK, "NounsTimelockV2");
        vm.label(NounsConstants.TOKEN, "NounsToken");
    }

    function test_proposal() public {
        proposalId = _proposalId();
        (targets, values, signatures, calldatas) = _generateCallData();

        _verifyManualCalldataAgainstChain();
        _verifyManualCalldataAgainstJson();
        _beforeProposal();

        assertEq(GOVERNOR.state(proposalId), uint8(ProposalState.Updatable), "proposal not Updatable");
        assertEq(GOVERNOR.timelock(), NounsConstants.TIMELOCK, "unexpected execution timelock");

        _rollAndWarp(_startBlock() + 1);
        assertEq(GOVERNOR.state(proposalId), uint8(ProposalState.Active), "proposal not Active");

        uint256 snapshotBlock = _startBlock();
        address[] memory voters = _voters();
        uint256 totalVotes;
        for (uint256 i = 0; i < voters.length; ++i) {
            totalVotes += NOUNS.getPriorVotes(voters[i], snapshotBlock);
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
        voters = new address[](15);
        voters[0] = 0x322956Ea3F126A68Fa6103965a75f6f4DA7AFFC9;
        voters[1] = 0x6Be8427159e0fddac30DDBE2892539846f5cd8aC;
        voters[2] = 0xC7CCEC521EEd20fCDdff8F95424816ac421c7d87;
        voters[3] = 0xf84a5Fd946A7714c6d48508FA8292c8c5037b5A8;
        voters[4] = 0xFC538FFD2923ddDaED09c8aD1a51686275C56183;
        voters[5] = 0xEDc1a397589A0236C4810883b7d559288a5Fe7e1;
        voters[6] = 0x0B44AdE372263aAd8f053160131f155DE0941485;
        voters[7] = 0x2117bf88b4Cb0186eaA87500A045fc998290E42a;
        voters[8] = 0xdfB6ed808fADddAd9154F5605E349fFF96E3d939;
        voters[9] = 0xae4705dC0816ee6d8a13F1C72780Ec5021915Fed;
        voters[10] = 0xDCb4117e3A00632efCaC3C169E0B23959f555E5e;
        voters[11] = 0x838149d482982a6AE93Ee99866bD48cf593f8298;
        voters[12] = 0xB875BADbd67c7D5fa2C845ddCE8FE112Fe383309;
        voters[13] = 0xF6e7501dFe7003299108020c5830C4c5B3CA6aA9;
        voters[14] = 0xD2355D2C0Fb7c992dF43DcAf5251A7f773CD0A7e;
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
        returns (
            address[] memory generatedTargets,
            uint256[] memory generatedValues,
            string[] memory generatedSignatures,
            bytes[] memory generatedCalldatas
        );
    function _beforeProposal() internal virtual;
    function _beforeExecution() internal virtual;
    function _afterExecution() internal virtual;
}
