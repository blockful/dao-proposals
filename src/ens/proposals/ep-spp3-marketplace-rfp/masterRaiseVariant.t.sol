// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IENSRegistryWithFallback } from "@ens/interfaces/IENSRegistryWithFallback.sol";
import { IEthTLDResolver } from "@ens/interfaces/IEthTLDResolver.sol";
import { IUSDCx } from "@ens/interfaces/IUSDCx.sol";
import { CFAv1Forwarder } from "@ens/interfaces/ISuperfluidCFAv1Forwarder.sol";

/**
 * @title Proposal_ENS_EP_SPP3_Marketplace_MasterRaise_Test
 * @notice ALTERNATIVE payload shape for the SPP3 Marketplace RFP award, per the forum's Next Steps:
 *         "On execution, the $90,000 up-front amount and the $100,000 performance reserve move to
 *         the Stream Management Pod, and the master stream is raised to fund the $310,000 stream."
 * @dev The primary reconstruction (calldataCheck.t.sol) reads the $310k as a lump transfer; this
 *      variant reads it as an EP 6.49-style raise of the timelock -> pod USDCx master stream. The
 *      forum marks the on-chain payload as "pending specification", so both shapes stay tested
 *      until the committee publishes the draft. MetaGov cannot do the raise itself — it holds no
 *      flowOperator permission on the timelock's flows — so under this reading the setFlowrate MUST
 *      be in the DAO executable.
 *
 *      Assumed parameter (unspecified by the forum): the raise spreads $310k from execution
 *      (~2026-09-10 per the forum's own schedule) to term end (2027-08-01), so the pod has accrued
 *      the full tranche by the time the cohort term closes. The committee could instead size it to
 *      the December-opening stream rate or another period — pin this before the draft.
 *
 *      EP 6.49's executable paired its raise with a USDC wrap and an autowrap-allowance refresh.
 *      The live autowrap allowance (timelock -> autowrapper) was ~4.55M USDC at review time, which
 *      covers the current $3.21M/yr master through term end but drains ~$310k faster under this
 *      raise — the committee's draft may therefore include an allowance refresh alongside it.
 */
contract Proposal_ENS_EP_SPP3_Marketplace_MasterRaise_Test is ENS_Governance {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDCx public constant USDCX = IUSDCx(0x1BA8603DA702602A8657980e825A6DAa03Dee93a);
    CFAv1Forwarder public constant SUPERFLUID = CFAv1Forwarder(0xcfA132E353cB4E398080B9700609bb008eceB125);

    address public constant STREAM_POD = 0xB162Bf7A7fD64eF32b787719335d06B2780e31D1; // stream.mg.wg.ens.eth

    uint256 public constant UPFRONT_INSTALLMENTS = 90_000 * 10 ** 6;
    uint256 public constant PERFORMANCE_GATES = 100_000 * 10 ** 6;
    uint256 public constant STREAM_TRANCHE_WAD = 310_000 ether;

    // The $3.21M/yr SPP3 master rate set by EP 6.49, live on mainnet.
    int96 public constant CURRENT_MASTER_RATE = 101_720_934_415_475_068;

    uint256 internal constant ASSUMED_EXEC = 1_788_998_400; // 2026-09-10, forum schedule
    uint256 internal constant TERM_END = 1_817_078_400; // 2027-08-01, cohort co-termination
    int96 public constant RAISED_MASTER_RATE =
        CURRENT_MASTER_RATE + int96(int256(STREAM_TRANCHE_WAD / (TERM_END - ASSUMED_EXEC)));

    uint256 podBalanceBefore;
    uint256 timelockBalanceBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_862_600, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x5BFCB4BE4d7B43437d5A0c57E908c048a4418390; // fireeyesdao.eth (pre-draft default)
    }

    function _beforeProposal() public override {
        // Pin the recipient to the name the spec uses.
        bytes32 node = namehash(bytes("stream.mg.wg.ens.eth"));
        address resolver = IENSRegistryWithFallback(ENSConstants.ENS_REGISTRY).resolver(node);
        assertEq(IEthTLDResolver(resolver).addr(node), STREAM_POD, "stream.mg.wg.ens.eth does not resolve to the pod");

        // The raise is relative, so the live rate must be exactly the EP 6.49 rate this variant
        // assumes — if the master moves before the draft, this fails loudly instead of encoding a
        // stale target rate.
        assertEq(
            SUPERFLUID.getFlowrate(address(USDCX), address(timelock), STREAM_POD),
            CURRENT_MASTER_RATE,
            "live master rate changed; re-derive the raise"
        );

        podBalanceBefore = USDC.balanceOf(STREAM_POD);
        timelockBalanceBefore = USDC.balanceOf(address(timelock));
        assertGe(timelockBalanceBefore, UPFRONT_INSTALLMENTS + PERFORMANCE_GATES, "timelock cannot cover the transfers");
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

        // 3. Raise the master stream to deliver the $310k stream tranche to the pod by term end.
        targets[2] = address(SUPERFLUID);
        calldatas[2] = abi.encodeWithSelector(
            CFAv1Forwarder.setFlowrate.selector, address(USDCX), STREAM_POD, RAISED_MASTER_RATE
        );

        description = "Pre-draft (master-raise variant): SPP3 Marketplace RFP award to Nomentum Labs";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(
            SUPERFLUID.getFlowrate(address(USDCX), address(timelock), STREAM_POD),
            RAISED_MASTER_RATE,
            "master stream not raised to the expected rate"
        );
        assertEq(
            USDC.balanceOf(STREAM_POD),
            podBalanceBefore + UPFRONT_INSTALLMENTS + PERFORMANCE_GATES,
            "pod did not receive the two USDC tranches"
        );
        assertEq(
            USDC.balanceOf(address(timelock)),
            timelockBalanceBefore - UPFRONT_INSTALLMENTS - PERFORMANCE_GATES,
            "timelock spent more than the two tranches"
        );
        // The raise increases the timelock's outflow immediately; it must not start underwater.
        assertGt(USDCX.balanceOf(address(timelock)), 0, "timelock USDCx empty at the raised rate");
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return ""; // Pre-draft: no proposalCalldata.json yet.
    }
}
