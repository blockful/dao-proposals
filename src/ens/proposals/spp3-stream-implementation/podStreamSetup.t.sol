// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { MultiSendHelper } from "@ens/helpers/MultiSendHelper.sol";
import { CFAv1Forwarder } from "@ens/interfaces/ISuperfluidCFAv1Forwarder.sol";
import { IUSDCx } from "@ens/interfaces/IUSDCx.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

// SPP3 stream implementation, pod side. The Stream Management Pod is a Gnosis Safe that runs the
// individual provider streams. Moving from the SPP2 cohort to SPP3 means, in one batch: turn off the
// providers that were not renewed, bump Namespace, and start Fluidkey and Goldsky. eth.limo, Blockful
// and Unruggable keep their existing streams. The result adds up to $3.09M/yr, matching the master.
//
// Per-provider rates use budget / 31_536_000 (365 days), which reproduces the pod's live rates exactly.
contract SPP3_PodStreamSetup_Test is Test, MultiSendHelper {
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDCX = 0x1BA8603DA702602A8657980e825A6DAa03Dee93a;
    CFAv1Forwarder public constant SUPERFLUID = CFAv1Forwarder(0xcfA132E353cB4E398080B9700609bb008eceB125);

    address public constant STREAM_POD = 0xB162Bf7A7fD64eF32b787719335d06B2780e31D1;
    address public constant TIMELOCK = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7; // an owner of the pod

    // SPP2 providers not renewed in SPP3: their streams are switched off.
    address public constant NAMEHASH = 0x4dC96AAd2Daa3f84066F3A00EC41Fd1e88c8865A; // $1.1M
    address public constant EFP = 0xE2Cded674643743ec1316858dFD4FD2116932E63; // $500k
    address public constant ZK_EMAIL = 0xca07423a99210D1a667b33901deADfAEdA687639; // $400k
    address public constant JUSTANAME = 0xdaBf4f1f58d9350731e218E25ACcaF91e0d01d33; // $300k

    // Two-year SPP2 streams, untouched.
    address public constant ETH_LIMO = 0xB352bB4E2A4f27683435f153A259f1B207218b1b; // $700k
    address public constant BLOCKFUL = 0x6dcc3939f811E22E9Faa5B2C591Fbdbf7Ee47Ee3; // $700k

    // SPP3 cohort.
    address public constant NAMESPACE = 0x168CAfEcFBE97dF85968Ea039CC11D10a9A44567; // $400k -> $500k
    address public constant UNRUGGABLE = 0x64Ca550F78d6Cc711B247319CC71A04A166707Ab; // $400k, unchanged
    address public constant FLUIDKEY = 0xdcC34c0da55cEF7AeD38Bb749AD97DAC12A9936C; // $340k, new
    address public constant GOLDSKY = 0x79d46b9a85F0CC040aE66186aDCa8e318b064485; // $450k, new

    uint256 internal constant SECONDS_PER_YEAR = 31_536_000;

    // The proposal executes in July; the switch is targeted for Aug 1 but is not bound on-chain. Last
    // season the pod-side restart slipped to mid-September, so the overlap test uses that as the worst case.
    uint256 internal constant EXEC_DATE = 1_784_419_200; // ~2026-07-19, proposal execution
    uint256 internal constant SWITCH_TARGET = 1_785_542_400; // 2026-08-01, intended switch
    uint256 internal constant SWITCH_WORST = 1_789_171_200; // ~2026-09-12, last season's actual slip
    int96 internal constant MASTER_FLOW_RATE = 97_918_282_661_625_533; // $3.09M/yr, the Layer 1 target

    // Margin the executable sends to the pod, sized to carry it ~65 days past execution.
    uint256 internal constant POD_MARGIN = 250_000 ether;

    function setUp() public {
        vm.createSelectFork({ blockNumber: 25_480_000, urlOrAlias: "mainnet" });
        vm.label(STREAM_POD, "streamPod");
        vm.label(TIMELOCK, "timelock");
    }

    function _flowRate(uint256 annualUSD) internal pure returns (int96) {
        return int96(int256(annualUSD * 1e18 / SECONDS_PER_YEAR));
    }

    function _outRate(address receiver) internal view returns (int96) {
        return SUPERFLUID.getFlowrate(USDCX, STREAM_POD, receiver);
    }

    // The switch as a single batch: everything flips at the same moment.
    function test_podStreamSetup() public {
        // The derived rates match the streams the pod is running today.
        assertEq(_outRate(NAMEHASH), _flowRate(1_100_000));
        assertEq(_outRate(EFP), _flowRate(500_000));
        assertEq(_outRate(ZK_EMAIL), _flowRate(400_000));
        assertEq(_outRate(JUSTANAME), _flowRate(300_000));
        assertEq(_outRate(ETH_LIMO), _flowRate(700_000));
        assertEq(_outRate(BLOCKFUL), _flowRate(700_000));
        assertEq(_outRate(NAMESPACE), _flowRate(400_000));
        assertEq(_outRate(UNRUGGABLE), _flowRate(400_000));
        assertEq(_outRate(FLUIDKEY), 0);
        assertEq(_outRate(GOLDSKY), 0);

        // Off streams first so their deposits free up before the new ones open.
        _podExecute(
            abi.encodePacked(
                _setFlowratePacked(NAMEHASH, 0),
                _setFlowratePacked(EFP, 0),
                _setFlowratePacked(ZK_EMAIL, 0),
                _setFlowratePacked(JUSTANAME, 0),
                _setFlowratePacked(NAMESPACE, _flowRate(500_000)),
                _setFlowratePacked(FLUIDKEY, _flowRate(340_000)),
                _setFlowratePacked(GOLDSKY, _flowRate(450_000))
            )
        );

        assertEq(_outRate(NAMEHASH), 0);
        assertEq(_outRate(EFP), 0);
        assertEq(_outRate(ZK_EMAIL), 0);
        assertEq(_outRate(JUSTANAME), 0);
        assertEq(_outRate(NAMESPACE), _flowRate(500_000));
        assertEq(_outRate(FLUIDKEY), _flowRate(340_000));
        assertEq(_outRate(GOLDSKY), _flowRate(450_000));
        assertEq(_outRate(UNRUGGABLE), _flowRate(400_000));
        assertEq(_outRate(ETH_LIMO), _flowRate(700_000));
        assertEq(_outRate(BLOCKFUL), _flowRate(700_000));

        // Total out now lines up with the $3.09M master in (within the ~$2k/yr rounding, see below).
        int96 expectedOut = _flowRate(700_000) + _flowRate(700_000) + _flowRate(500_000) + _flowRate(400_000)
            + _flowRate(340_000) + _flowRate(450_000);
        int96 masterIn = SUPERFLUID.getFlowrate(USDCX, TIMELOCK, STREAM_POD);
        assertEq(SUPERFLUID.getAccountFlowrate(USDCX, STREAM_POD), masterIn - expectedOut);
        console2.log("pod SPP3 outflow:", uint256(int256(expectedOut)));
    }

    // The proposal executes in July and the master immediately moves to $3.09M, but the SPP2 cohort keeps
    // its old $4.5M streams until the pod switches. Aug 1 is the target, but last season the pod-side
    // restart slipped to mid-September, so this models that: master down at execution (Jul 19), pod pays
    // the old cohort until Sep 12. The margin the executable sent has to carry the shortfall the whole way.
    function test_transitionOverlap_margin() public {
        // Stand in for the Layer 1 wrap plus autowrap so the timelock's master stream stays funded across
        // the long window. This test is about the pod, not the timelock.
        vm.startPrank(TIMELOCK);
        IERC20(USDC).approve(USDCX, 1_000_000e6);
        IUSDCx(USDCX).upgrade(1_000_000 ether);
        vm.stopPrank();

        // Execution: send the margin and drop the master to the new rate. Providers unchanged.
        vm.warp(EXEC_DATE);
        vm.startPrank(TIMELOCK);
        IUSDCx(USDCX).transfer(STREAM_POD, POD_MARGIN);
        SUPERFLUID.setFlowrate(USDCX, STREAM_POD, MASTER_FLOW_RATE);
        vm.stopPrank();

        // The margin has to cover the shortfall (old outflow minus new inflow) over the whole overlap.
        int96 oldOutflow = _flowRate(1_100_000) + _flowRate(700_000) + _flowRate(700_000) + _flowRate(500_000)
            + _flowRate(400_000) + _flowRate(400_000) + _flowRate(400_000) + _flowRate(300_000);
        uint256 shortfall = uint256(int256(oldOutflow - MASTER_FLOW_RATE)) * (SWITCH_WORST - EXEC_DATE);
        assertGt(POD_MARGIN, shortfall, "margin must cover the worst-case overlap");

        // Pod pays the old cohort on the reduced inflow the whole time, then switches.
        vm.warp(SWITCH_WORST);
        uint256 balanceAtSwitch = _podBalance();
        assertGt(balanceAtSwitch, 0);

        _podExecute(
            abi.encodePacked(
                _setFlowratePacked(NAMEHASH, 0),
                _setFlowratePacked(EFP, 0),
                _setFlowratePacked(ZK_EMAIL, 0),
                _setFlowratePacked(JUSTANAME, 0),
                _setFlowratePacked(NAMESPACE, _flowRate(500_000)),
                _setFlowratePacked(FLUIDKEY, _flowRate(340_000)),
                _setFlowratePacked(GOLDSKY, _flowRate(450_000))
            )
        );

        // Out and in match to within ~$2k/yr by design (see the dual-convention note), so from here the
        // pod is effectively steady.
        vm.warp(SWITCH_WORST + 3 days);
        assertGt(_podBalance(), 0);

        assertEq(_outRate(FLUIDKEY), _flowRate(340_000));
        assertEq(_outRate(GOLDSKY), _flowRate(450_000));
        assertEq(_outRate(NAMESPACE), _flowRate(500_000));
        assertEq(_outRate(NAMEHASH), 0);
        console2.log("overlap days:", (SWITCH_WORST - EXEC_DATE) / 1 days);
        console2.log("pod buffer at switch:", balanceAtSwitch / 1e18);
    }

    // Run the batch as the pod. Threshold is 1 and the timelock is an owner, so a pre-approved
    // signature from the timelock is enough.
    function _podExecute(bytes memory batch) internal {
        (address target, bytes memory execCalldata) = _buildSafeMultiSendCalldata(batch, STREAM_POD, TIMELOCK);
        vm.prank(TIMELOCK);
        (bool ok,) = target.call(execCalldata);
        assertTrue(ok, "pod execTransaction failed");
    }

    function _podBalance() internal view returns (uint256) {
        return IUSDCx(USDCX).balanceOf(STREAM_POD);
    }

    function _setFlowratePacked(address receiver, int96 rate) internal pure returns (bytes memory) {
        bytes memory inner = abi.encodeWithSelector(CFAv1Forwarder.setFlowrate.selector, USDCX, receiver, rate);
        return _packCall(address(SUPERFLUID), inner);
    }
}
