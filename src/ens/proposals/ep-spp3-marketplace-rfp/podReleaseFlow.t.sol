// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { MultiSendHelper } from "@ens/helpers/MultiSendHelper.sol";
import { CFAv1Forwarder } from "@ens/interfaces/ISuperfluidCFAv1Forwarder.sol";
import { IUSDCx } from "@ens/interfaces/IUSDCx.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

// SPP3 Marketplace RFP award, pod side. The DAO executable (calldataCheck.t.sol) only funds the
// Stream Management Pod; every release is a pod Safe transaction. In production the pod (threshold 1,
// owners = timelock + main.mg.wg.ens.eth) is driven by the MetaGov Safe as owner: the MGWG signers
// approve a tx on their own Safe whose payload is the pod's execTransaction with MetaGov's
// pre-approved signature — the "nested safe" path. Every release below is executed through that exact
// path (vm.prank(METAGOV) stands in for the MGWG signers reaching their own 2-of-N threshold).
//
// Simulated against live mainnet state, where the SPP3 cohort switch has already executed and the pod
// runs steady at ~$3.21M/yr in/out with a ~209k USDCx buffer:
//   1. Execution (~Oct 2026):  timelock sends 90k + 100k + 310k USDC to the pod.
//   2. Oct/Nov/Dec 2026:       three $30k USDC installments to Nomentum Labs.
//   3. Dec 2026 (ENSv2 gate):  pod wraps 310k to USDCx and opens the stream, running to term end.
//   4. Apr 2027 / term end:    2 + 2 performance gates of $25k, or the 100k returns to the treasury.
//   5. Term end (Aug 2027):    stream closed; Nomentum has received ~310k USDCx + 190k USDC.
//
// Nomentum Labs's payout address is not yet public (post-KYC); a placeholder EOA stands in. The $25k
// wind-down escrow is "funded from the award when the stream opens" but its destination and which
// tranche it reduces are not specified — not modeled here, confirm with MetaGov before the pod batch.
contract SPP3_Marketplace_PodReleaseFlow_Test is Test, MultiSendHelper {
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDCX = 0x1BA8603DA702602A8657980e825A6DAa03Dee93a;
    CFAv1Forwarder public constant SUPERFLUID = CFAv1Forwarder(0xcfA132E353cB4E398080B9700609bb008eceB125);

    address public constant STREAM_POD = 0xB162Bf7A7fD64eF32b787719335d06B2780e31D1; // stream.mg.wg.ens.eth
    address public constant TIMELOCK = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7; // pod owner
    address public constant METAGOV = 0x91c32893216dE3eA0a55ABb9851f581d4503d39b; // main.mg.wg.ens.eth, pod owner

    // Cohort streams the release flow must not disturb.
    address public constant NAMESPACE = 0x168CAfEcFBE97dF85968Ea039CC11D10a9A44567;
    address public constant GOLDSKY = 0x79d46b9a85F0CC040aE66186aDCa8e318b064485;
    address public constant ETH_LIMO = 0xB352bB4E2A4f27683435f153A259f1B207218b1b;

    // Award tranches.
    uint256 public constant UPFRONT = 90_000e6;
    uint256 public constant GATES = 100_000e6;
    uint256 public constant STREAM_USDC = 310_000e6;
    uint256 public constant STREAM_WAD = 310_000 ether;
    uint256 public constant INSTALLMENT = 30_000e6;
    uint256 public constant GATE = 25_000e6;

    // Timeline. Execution assumed late September (recommendation posted 2026-08-27); installments over
    // the first quarter; stream open on the ENSv2 readiness target (~December); term co-terminating
    // with the SPP3 cohort (ratified July 2026, one-year term -> Aug 1 2027).
    uint256 internal constant EXEC_DATE = 1_790_553_600; // 2026-09-28
    uint256 internal constant INSTALL_1 = 1_790_812_800; // 2026-10-01
    uint256 internal constant INSTALL_2 = 1_793_491_200; // 2026-11-01
    uint256 internal constant INSTALL_3 = 1_796_083_200; // 2026-12-01
    uint256 internal constant STREAM_OPEN = 1_796_083_200; // 2026-12-01
    uint256 internal constant GATE_Q1 = 1_807_747_200; // 2027-04-15, after Q1 results verify
    uint256 internal constant TERM_END = 1_817_078_400; // 2027-08-01

    int96 internal constant STREAM_RATE = int96(int256(STREAM_WAD / (TERM_END - STREAM_OPEN)));

    // Placeholder until the post-KYC payout address is published.
    address internal nomentum = makeAddr("nomentumLabs");

    int96 internal preNamespace;
    int96 internal preGoldsky;
    int96 internal preEthLimo;

    function setUp() public {
        vm.createSelectFork({ blockNumber: 25_862_600, urlOrAlias: "mainnet" });
        vm.label(STREAM_POD, "streamPod");
        vm.label(METAGOV, "metagovSafe");
        vm.label(TIMELOCK, "timelock");

        preNamespace = _outRate(NAMESPACE);
        preGoldsky = _outRate(GOLDSKY);
        preEthLimo = _outRate(ETH_LIMO);

        // Stand in for autowrap over the 11-month horizon so the master stream stays funded; in
        // production the autowrap keeps topping up the timelock's USDCx.
        vm.startPrank(TIMELOCK);
        IERC20(USDC).approve(USDCX, 3_500_000e6);
        IUSDCx(USDCX).upgrade(3_500_000 ether);
        vm.stopPrank();
    }

    // Happy path: installments, stream, all four gates released.
    function test_podReleaseLifecycle() public {
        _daoExecutableFunds();

        // First-quarter installments, one pod tx each.
        uint256[3] memory installDates = [INSTALL_1, INSTALL_2, INSTALL_3];
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(installDates[i]);
            _metagovPodCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, INSTALLMENT));
            assertEq(IERC20(USDC).balanceOf(nomentum), INSTALLMENT * (i + 1), "installment not received");
            assertGt(IUSDCx(USDCX).balanceOf(STREAM_POD), 0, "pod insolvent during installments");
        }

        _openStream();

        // The pod stays solvent all the way to term end: the 310k wrap covers the Nomentum stream by
        // construction, and the pre-existing ~209k buffer absorbs the cohort's ~$2k/yr rounding drain.
        for (uint256 t = STREAM_OPEN; t < TERM_END; t += 30 days) {
            vm.warp(t);
            assertGt(IUSDCx(USDCX).balanceOf(STREAM_POD), 0, "pod went insolvent mid-term");
        }

        // Q1 2027 gates: revenue baseline held and 150+ active wallets, $25k each.
        vm.warp(GATE_Q1);
        _metagovPodBatch(
            bytes.concat(
                _packCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, GATE)),
                _packCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, GATE))
            ),
            "q1 gates"
        );

        // Term end: close the stream and release the last two gates ($1M pace, 250 ETH volume).
        vm.warp(TERM_END);
        _metagovPodBatch(
            bytes.concat(
                _packCall(
                    address(SUPERFLUID),
                    abi.encodeWithSelector(CFAv1Forwarder.setFlowrate.selector, USDCX, nomentum, int96(0))
                ),
                _packCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, GATE)),
                _packCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, GATE))
            ),
            "term end"
        );

        // Nomentum received the full award: 90k installments + 100k gates in USDC, ~310k streamed.
        assertEq(IERC20(USDC).balanceOf(nomentum), UPFRONT + GATES, "USDC releases wrong");
        assertApproxEqAbs(IUSDCx(USDCX).balanceOf(nomentum), STREAM_WAD, 1e18, "streamed total wrong");
        assertEq(_outRate(nomentum), 0, "stream not closed");

        _assertPodSteadyAndCohortUntouched();
    }

    // Miss path: no gate is verified, so at term end the 100k goes back to the treasury.
    function test_gatesMissed_fundsReturnToTreasury() public {
        _daoExecutableFunds();

        vm.warp(INSTALL_1);
        _metagovPodCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, INSTALLMENT));
        vm.warp(INSTALL_2);
        _metagovPodCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, INSTALLMENT));
        vm.warp(INSTALL_3);
        _metagovPodCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, nomentum, INSTALLMENT));
        _openStream();

        uint256 timelockUSDCBefore = IERC20(USDC).balanceOf(TIMELOCK);

        vm.warp(TERM_END);
        _metagovPodBatch(
            bytes.concat(
                _packCall(
                    address(SUPERFLUID),
                    abi.encodeWithSelector(CFAv1Forwarder.setFlowrate.selector, USDCX, nomentum, int96(0))
                ),
                _packCall(USDC, abi.encodeWithSelector(IERC20.transfer.selector, TIMELOCK, GATES))
            ),
            "term end, gates missed"
        );

        assertEq(IERC20(USDC).balanceOf(TIMELOCK), timelockUSDCBefore + GATES, "unreleased gates not returned");
        assertEq(IERC20(USDC).balanceOf(nomentum), UPFRONT, "only installments should have paid out");
        assertApproxEqAbs(IUSDCx(USDCX).balanceOf(nomentum), STREAM_WAD, 1e18, "streamed total wrong");

        _assertPodSteadyAndCohortUntouched();
    }

    // The DAO executable's effect: three USDC transfers timelock -> pod. The full governance
    // lifecycle for these is covered by calldataCheck.t.sol.
    function _daoExecutableFunds() internal {
        vm.warp(EXEC_DATE);
        uint256 podBefore = IERC20(USDC).balanceOf(STREAM_POD);
        vm.startPrank(TIMELOCK);
        IERC20(USDC).transfer(STREAM_POD, UPFRONT);
        IERC20(USDC).transfer(STREAM_POD, GATES);
        IERC20(USDC).transfer(STREAM_POD, STREAM_USDC);
        vm.stopPrank();
        assertEq(IERC20(USDC).balanceOf(STREAM_POD), podBefore + UPFRONT + GATES + STREAM_USDC);
    }

    // The ENSv2-readiness batch: wrap the stream tranche and open the flow, one pod tx.
    function _openStream() internal {
        vm.warp(STREAM_OPEN);
        uint256 podUSDCxBefore = IUSDCx(USDCX).balanceOf(STREAM_POD);
        _metagovPodBatch(
            bytes.concat(
                _packCall(USDC, abi.encodeWithSelector(IERC20.approve.selector, USDCX, STREAM_USDC)),
                _packCall(USDCX, abi.encodeWithSelector(IUSDCx.upgrade.selector, STREAM_WAD)),
                _packCall(
                    address(SUPERFLUID),
                    abi.encodeWithSelector(CFAv1Forwarder.setFlowrate.selector, USDCX, nomentum, STREAM_RATE)
                )
            ),
            "stream open"
        );
        assertEq(_outRate(nomentum), STREAM_RATE, "stream rate wrong");
        // Wrapped amount lands minus the Superfluid buffer deposit the new flow takes.
        assertApproxEqAbs(IUSDCx(USDCX).balanceOf(STREAM_POD), podUSDCxBefore + STREAM_WAD, 1000e18);
    }

    // A single call executed by the MetaGov Safe as pod owner (threshold 1, pre-approved signature).
    function _metagovPodCall(address to, bytes memory data) internal {
        (address target, bytes memory execData) = _buildSafeExecCalldata(STREAM_POD, to, data, METAGOV);
        vm.prank(METAGOV);
        (bool ok, bytes memory ret) = target.call(execData);
        assertTrue(ok, "pod execTransaction reverted");
        assertTrue(abi.decode(ret, (bool)), "pod execTransaction returned false");
    }

    // A MultiSend batch executed the same way. Logs the exact Safe Transaction Builder bytes
    // (to = pod, value = 0) the MGWG signers would submit.
    function _metagovPodBatch(bytes memory batch, string memory tag) internal {
        (address target, bytes memory execData) = _buildSafeMultiSendCalldata(batch, STREAM_POD, METAGOV);
        vm.prank(METAGOV);
        (bool ok, bytes memory ret) = target.call(execData);
        assertTrue(ok, "pod execTransaction reverted");
        assertTrue(abi.decode(ret, (bool)), "pod execTransaction returned false");
        console2.log("SafeTxBuilder bytes for:", tag);
        console2.logBytes(execData);
    }

    function _assertPodSteadyAndCohortUntouched() internal view {
        assertGt(IUSDCx(USDCX).balanceOf(STREAM_POD), 0, "pod not solvent at term end");
        assertEq(_outRate(NAMESPACE), preNamespace, "Namespace stream disturbed");
        assertEq(_outRate(GOLDSKY), preGoldsky, "Goldsky stream disturbed");
        assertEq(_outRate(ETH_LIMO), preEthLimo, "eth.limo stream disturbed");
    }

    function _outRate(address receiver) internal view returns (int96) {
        return SUPERFLUID.getFlowrate(USDCX, STREAM_POD, receiver);
    }
}
