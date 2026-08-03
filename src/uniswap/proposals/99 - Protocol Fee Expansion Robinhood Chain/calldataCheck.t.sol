// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Vm } from "@forge-std/src/Vm.sol";
import { UNI_Governance } from "@uniswap/uniswap.t.sol";
import { IArbitrumInbox } from "@uniswap/interfaces/IArbitrumInbox.sol";
import { IV2Factory } from "@uniswap/interfaces/IV2Factory.sol";
import { IV3Factory } from "@uniswap/interfaces/IV3Factory.sol";

contract Proposal_UNI_99_Protocol_Fee_Expansion_Robinhood_Chain_Test is UNI_Governance {
    IArbitrumInbox public constant RH_INBOX = IArbitrumInbox(0x1A07cc4BD17E0118BdB54D70990D2158AbAD7a2D);
    IV2Factory public constant RH_V2_FACTORY = IV2Factory(0x8bcEaA40B9AcdfAedF85AdF4FF01F5Ad6517937f);
    IV3Factory public constant RH_V3_FACTORY = IV3Factory(0x1f7d7550B1b028f7571E69A784071F0205FD2EfA);

    address public constant ALIASED_TIMELOCK = 0x2BAD8182C09F50c8318d769245beA52C32Be46CD;
    address public constant RH_TOKEN_JAR = 0x2aC03e14Cfe755426DaAEe0a4994184Ce81482F8;
    address public constant RH_V3_OPEN_FEE_ADAPTER = 0x05C420bC4823e039AA4dA645eDde743486dAAA25;
    address public constant L1_TO_L2_ALIAS_OFFSET = 0x1111000000000000000000000000000000001111;

    uint256 public constant RETRYABLE_TICKET_VALUE = 10_020_000_000_000_000;
    uint256 public constant MAX_SUBMISSION_COST = 10_000_000_000_000_000;
    uint256 public constant GAS_LIMIT = 200_000;
    uint256 public constant MAX_FEE_PER_GAS = 100_000_000;

    uint256 private governorBalanceBefore;
    uint256 private timelockBalanceBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_554_766, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x50EC05ADe8280758E2077fcBC08D878D4aef79C3;
    }

    function _beforeProposal() public override {
        governorBalanceBefore = address(governor).balance;
        timelockBalanceBefore = address(timelock).balance;

        assertGt(address(RH_INBOX).code.length, 0, "Robinhood Inbox must be deployed on Ethereum");
        assertEq(ALIASED_TIMELOCK, _applyL1ToL2Alias(address(timelock)), "Incorrect L2 timelock alias");
        assertEq(
            RETRYABLE_TICKET_VALUE,
            MAX_SUBMISSION_COST + GAS_LIMIT * MAX_FEE_PER_GAS,
            "Retryable ticket value must exactly cover submission and gas"
        );

        // The shared harness calls execute without msg.value. Fund the Governor with exactly
        // the ETH that a real proposal executor must supply for both retryable tickets.
        vm.deal(address(governor), governorBalanceBefore + RETRYABLE_TICKET_VALUE * 2);

        vm.recordLogs();
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        proposalId = 99;
        targets = new address[](2);
        values = new uint256[](2);
        signatures = new string[](2);
        calldatas = new bytes[](2);

        bytes memory setV2FeeCollector = abi.encodeWithSelector(IV2Factory.setFeeTo.selector, RH_TOKEN_JAR);
        bytes memory transferV3Ownership = abi.encodeWithSelector(IV3Factory.setOwner.selector, RH_V3_OPEN_FEE_ADAPTER);

        targets[0] = address(RH_INBOX);
        values[0] = RETRYABLE_TICKET_VALUE;
        signatures[0] = "";
        calldatas[0] = abi.encodeWithSelector(
            IArbitrumInbox.createRetryableTicket.selector,
            address(RH_V2_FACTORY),
            0,
            MAX_SUBMISSION_COST,
            ALIASED_TIMELOCK,
            ALIASED_TIMELOCK,
            GAS_LIMIT,
            MAX_FEE_PER_GAS,
            setV2FeeCollector
        );

        targets[1] = address(RH_INBOX);
        values[1] = RETRYABLE_TICKET_VALUE;
        signatures[1] = "";
        calldatas[1] = abi.encodeWithSelector(
            IArbitrumInbox.createRetryableTicket.selector,
            address(RH_V3_FACTORY),
            0,
            MAX_SUBMISSION_COST,
            ALIASED_TIMELOCK,
            ALIASED_TIMELOCK,
            GAS_LIMIT,
            MAX_FEE_PER_GAS,
            transferV3Ownership
        );

        description = getDescriptionFromMarkdown();
        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(
            address(governor).balance,
            governorBalanceBefore,
            "Governor must spend the exact value of both retryable tickets"
        );
        assertEq(
            address(timelock).balance,
            timelockBalanceBefore,
            "Timelock must pass through, not retain, retryable ticket ETH"
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 inboxMessageDelivered = keccak256("InboxMessageDelivered(uint256,bytes)");
        uint256 deliveredMessages;

        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].emitter == address(RH_INBOX) && entries[i].topics.length > 0
                    && entries[i].topics[0] == inboxMessageDelivered
            ) {
                deliveredMessages++;
            }
        }

        assertEq(deliveredMessages, 2, "Robinhood Inbox must deliver one message per proposal call");
    }

    function _applyL1ToL2Alias(address l1Address) internal pure returns (address l2Alias) {
        unchecked {
            l2Alias = address(uint160(l1Address) + uint160(L1_TO_L2_ALIAS_OFFSET));
        }
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/uniswap/proposals/99 - Protocol Fee Expansion Robinhood Chain";
    }
}
