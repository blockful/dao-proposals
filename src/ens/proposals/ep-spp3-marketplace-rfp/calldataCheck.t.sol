// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IEthTLDResolver } from "@ens/interfaces/IEthTLDResolver.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";

/**
 * @title Proposal_ENS_EP_SPP3_Marketplace_RFP_Test
 * @notice Live calldata review for the SPP3 Marketplace RFP award (Nomentum Labs / Grails).
 * @dev Forum: https://discuss.ens.domains/t/spp3-marketplace-rfp-recommendation/22371
 *      On-chain id 19667497...920394, proposed by coltron.eth at block 25,877,353 (2026-08-31).
 *      The live payload settled on the lump three-transfer shape (not the master-stream raise the
 *      forum's Next Steps sketched); the three calls were verified byte-for-byte against the
 *      ProposalCreated event, and the description file is byte-identical to the event's.
 *
 * The DAO-side executable moves the full $500k award to the MetaGov Stream Management Pod
 * (stream.mg.wg.ens.eth, the same pod that runs the SPP3 cohort streams from EP 6.49) in three
 * transfers, one per tranche of the payment structure, so each tranche is legible on-chain:
 *
 *   1. $90,000  — released by MetaGov to Nomentum Labs as $30k monthly installments over the
 *                 first quarter, subject to KYC and the executed Award Notice.
 *   2. $100,000 — held in the pod for the four $25k performance gates, released only on
 *                 verified results (unreleased funds return to the treasury at term end).
 *   3. $310,000 — funds the stream MetaGov opens from the pod on committee verification of
 *                 the ENSv2 readiness milestone (target Q4 2026), running to term end.
 *
 * Release mechanics (installments, gates, stream open, wind-down escrow) are pod-side Safe
 * transactions by the MetaGov stewards, not part of this executable.
 */
contract Proposal_ENS_EP_SPP3_Marketplace_RFP_Test is ENS_Governance {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // MetaGov Stream Management Pod (stream.mg.wg.ens.eth), master stream receiver since EP 6.13/6.49.
    address public constant STREAM_POD = 0xB162Bf7A7fD64eF32b787719335d06B2780e31D1;

    // USDC has 6 decimals.
    uint256 public constant UPFRONT_INSTALLMENTS = 90_000 * 10 ** 6;
    uint256 public constant PERFORMANCE_GATES = 100_000 * 10 ** 6;
    uint256 public constant STREAM_TRANCHE = 310_000 * 10 ** 6;
    uint256 public constant TOTAL_AWARD = UPFRONT_INSTALLMENTS + PERFORMANCE_GATES + STREAM_TRANCHE;

    uint256 podBalanceBefore;
    uint256 timelockBalanceBefore;

    function _selectFork() public override {
        // Block the proposal was created at (voting starts the next block).
        vm.createSelectFork({ blockNumber: 25_877_353, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // coltron.eth, on-chain proposer
    }

    function _beforeProposal() public override {
        assertEq(TOTAL_AWARD, 500_000 * 10 ** 6, "award must total the $500k RFP maximum");

        // The recipient constant is the single point where a lookalike address could slip through
        // every balance assertion, so pin it to the name the spec uses: resolve stream.mg.wg.ens.eth
        // on-fork and require it to be the pod.
        bytes32 node = namehash(bytes("stream.mg.wg.ens.eth"));
        address resolver = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY).resolver(node);
        assertEq(IEthTLDResolver(resolver).addr(node), STREAM_POD, "stream.mg.wg.ens.eth does not resolve to the pod");

        // The pod must be a Safe the timelock co-owns — the property that keeps unreleased award
        // funds recoverable by the DAO at term end.
        address[] memory owners = ISafe(STREAM_POD).getOwners();
        bool timelockIsOwner;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == address(timelock)) timelockIsOwner = true;
        }
        assertTrue(timelockIsOwner, "timelock is not an owner of the stream pod");

        podBalanceBefore = USDC.balanceOf(STREAM_POD);
        timelockBalanceBefore = USDC.balanceOf(address(timelock));
        assertGe(timelockBalanceBefore, TOTAL_AWARD, "timelock cannot cover the award");
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 numTransactions = 3;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. $90k upfront tranche, paid out by MetaGov in $30k monthly installments.
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(USDC.transfer.selector, STREAM_POD, UPFRONT_INSTALLMENTS);

        // 2. $100k held for the four $25k performance gates.
        targets[1] = address(USDC);
        calldatas[1] = abi.encodeWithSelector(USDC.transfer.selector, STREAM_POD, PERFORMANCE_GATES);

        // 3. $310k funding the ENSv2-readiness stream (opened by the pod ~December).
        targets[2] = address(USDC);
        calldatas[2] = abi.encodeWithSelector(USDC.transfer.selector, STREAM_POD, STREAM_TRANCHE);

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(USDC.balanceOf(STREAM_POD), podBalanceBefore + TOTAL_AWARD, "pod did not receive the full award");
        assertEq(
            USDC.balanceOf(address(timelock)), timelockBalanceBefore - TOTAL_AWARD, "timelock spent more than the award"
        );
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Live on-chain.
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-spp3-marketplace-rfp";
    }
}
