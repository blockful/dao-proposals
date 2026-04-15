// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";

interface IDNSSECImpl {
    function algorithms(uint8) external view returns (address);
    function setAlgorithm(uint8 id, address algo) external;
    function owner() external view returns (address);
}

contract Proposal_ENS_EP_6_40_Draft_Test is ENS_Governance {
    // ── Contracts ──────────────────────────────────────────────────────
    IDNSSECImpl public constant dnssecImpl = IDNSSECImpl(0x0fc3152971714E5ed7723FAFa650F86A4BaF30C5);

    // ── DNSSEC Algorithm IDs (RFC 8624) ────────────────────────────────
    uint8 public constant ALGO_RSASHA1 = 5;
    uint8 public constant ALGO_RSASHA1_NSEC3_SHA1 = 7;

    // ── Algorithm contract addresses ──────────────────────────────────
    /// @dev Same patched RSASHA1Algorithm contract already serving algorithm 5
    address public constant PATCHED_RSASHA1 = 0x58E0383E21f25DaB957F6664240445A514E9f5e8;

    /// @dev Pre-patch contract that algorithm 7 currently points to
    address public constant OLD_RSASHA1 = 0x6ca8624Bc207F043D140125486De0f7E624e37A1;

    // ── State captured before execution ────────────────────────────────
    address public algo7Before;

    function _selectFork() public override {
        vm.createSelectFork({ urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        // Verify access control: timelock must own DNSSECImpl
        assertEq(dnssecImpl.owner(), address(timelock), "DNSSECImpl should be owned by timelock");

        // Capture current algorithm 7 address
        algo7Before = dnssecImpl.algorithms(ALGO_RSASHA1_NSEC3_SHA1);

        // Algorithm 7 should still point to the old (unpatched) contract
        assertEq(algo7Before, OLD_RSASHA1, "Algorithm 7 should point to old unpatched contract");

        // Algorithm 5 should already point to the patched contract (done in EP 6.35)
        assertEq(
            dnssecImpl.algorithms(ALGO_RSASHA1),
            PATCHED_RSASHA1,
            "Algorithm 5 should already use patched RSASHA1"
        );

        // Verify the patched contract is deployed
        assertGt(PATCHED_RSASHA1.code.length, 0, "Patched RSASHA1Algorithm should be deployed");
    }

    function _generateCallData()
        public
        override
        returns (
            address[] memory,
            uint256[] memory,
            string[] memory,
            bytes[] memory,
            string memory
        )
    {
        uint256 numTransactions = 1;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // TX1: Set algorithm 7 (RSASHA1-NSEC3-SHA1) to the same patched RSASHA1Algorithm
        // that already serves algorithm 5
        targets[0] = address(dnssecImpl);
        values[0] = 0;
        signatures[0] = "";
        calldatas[0] = abi.encodeWithSelector(
            IDNSSECImpl.setAlgorithm.selector,
            ALGO_RSASHA1_NSEC3_SHA1,
            PATCHED_RSASHA1
        );

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public view override {
        // Algorithm 7 should now point to the patched contract
        assertEq(
            dnssecImpl.algorithms(ALGO_RSASHA1_NSEC3_SHA1),
            PATCHED_RSASHA1,
            "Algorithm 7 should be updated to patched RSASHA1"
        );

        // Algorithm 5 should remain unchanged (still patched)
        assertEq(
            dnssecImpl.algorithms(ALGO_RSASHA1),
            PATCHED_RSASHA1,
            "Algorithm 5 should still use patched RSASHA1"
        );

        // Algorithms 5 and 7 should now point to the same contract
        assertEq(
            dnssecImpl.algorithms(ALGO_RSASHA1),
            dnssecImpl.algorithms(ALGO_RSASHA1_NSEC3_SHA1),
            "Algorithms 5 and 7 should share the same contract"
        );
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false; // Draft — not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-draft-2835574267465172124";
    }
}
