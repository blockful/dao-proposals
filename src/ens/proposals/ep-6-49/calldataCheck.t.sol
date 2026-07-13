// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IUSDCx } from "@ens/interfaces/IUSDCx.sol";
import { CFAv1Forwarder } from "@ens/interfaces/ISuperfluidCFAv1Forwarder.sol";

// SPP3 stream implementation, DAO side. Same shape as the SPP2 executable (EP 6.13), plus the
// committee's upfront payment. It wraps a month of funding plus a margin for the pod, sends the margin
// over, points the master USDCx stream at the Stream Management Pod, refreshes the autowrap allowance,
// and pays the committee's 20% lump sum in USDC. The pod sets each provider stream and the committee's
// 80% stream itself; that half lives in podStreamSetup.t.sol.
contract Proposal_ENS_EP_6_49_Test is ENS_Governance {
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDCx public constant USDCx = IUSDCx(0x1BA8603DA702602A8657980e825A6DAa03Dee93a);
    CFAv1Forwarder public constant SUPERFLUID = CFAv1Forwarder(0xcfA132E353cB4E398080B9700609bb008eceB125);

    address public constant STREAM_POD = 0xB162Bf7A7fD64eF32b787719335d06B2780e31D1; // stream.mg.wg.ens.eth
    address public constant AUTOWRAPPER = 0x1D65c6d3AD39d454Ea8F682c49aE7744706eA96d;

    // $3.21M/yr: the SPP3 cohort ($1.69M), the two SPP2 streams still running into next year (eth.limo
    // and Blockful, $1.4M), and the committee salary streams ($120k, the 80% streamed portion of the
    // $150k comp). Rate is budget / 31,556,926, the convention the SPP2 master used.
    int96 public constant MASTER_FLOW_RATE = 101_720_934_415_475_068;

    // We wrap one month of funding (267,500) plus the pod margin (250,000) and approve/upgrade the sum.
    uint256 public constant WRAP_USDC = 517_500_000_000; // 6 decimals
    uint256 public constant WRAP_USDCX = 517_500_000_000_000_000_000_000; // 18 decimals
    // Margin sent to the pod. The master moves to the new $3.21M rate the moment this executes (July),
    // but the pod keeps paying the SPP2 cohort the old $4.5M until the switch, running at about
    // -$1.41M/yr ($3,869/day). 250,000 carries the pod ~65 days past execution. The switch date is not
    // enforced on-chain and last season the pod-side restart slipped to mid-September, so size for a slip.
    uint256 public constant POD_MARGIN = 250_000_000_000_000_000_000_000;
    uint256 public constant AUTOWRAP_ALLOWANCE = 4_547_500_000_000; // ~17 months, same ratio SPP2 used

    // Committee upfront payment: the 20% lump sum, paid straight to each member in USDC (the 80% is
    // streamed by the pod). gregskril.eth is the non-compensated fifth member.
    address public constant COLTRON = 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359; // chair
    address public constant SOVEREIGNSIGNAL = 0x2D7d6Ec6198ADFD5850D00BD601958F6E316b05E;
    address public constant AUSTINGRIFFITH = 0x34aA3F359A9D614239015126635CE7732c18fDF3;
    address public constant ABDULLAHUMAR = 0xaA4a9282594a8ec02116fc97B634648CCc9fBe5f;
    uint256 public constant LUMP_CHAIR = 9_000_000_000; // 20% of $45k
    uint256 public constant LUMP_MEMBER = 7_000_000_000; // 20% of $35k

    int96 flowRateBefore;
    uint256 podBalanceBefore;
    uint256 timelockBalanceBefore;
    uint256 coltronUsdcBefore;
    uint256 svUsdcBefore;
    uint256 agUsdcBefore;
    uint256 auUsdcBefore;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_496_915, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        // coltron.eth, SPP3 committee chair and the on-chain proposer of EP 6.49.
        return 0x1D5460F896521aD685Ea4c3F2c679Ec0b6806359;
    }

    function _beforeProposal() public override {
        // The master is still the SPP2 rate ($4.5M); SPP3 lowers it as the one-year streams end.
        flowRateBefore = SUPERFLUID.getFlowrate(address(USDCx), address(timelock), STREAM_POD);
        assertGt(flowRateBefore, MASTER_FLOW_RATE);

        podBalanceBefore = USDCx.balanceOf(STREAM_POD);
        timelockBalanceBefore = USDCx.balanceOf(address(timelock));
        coltronUsdcBefore = USDC.balanceOf(COLTRON);
        svUsdcBefore = USDC.balanceOf(SOVEREIGNSIGNAL);
        agUsdcBefore = USDC.balanceOf(AUSTINGRIFFITH);
        auUsdcBefore = USDC.balanceOf(ABDULLAHUMAR);
        console2.log("master flow rate before:", uint256(int256(flowRateBefore)));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        description = getDescriptionFromMarkdown();

        address[] memory _targets = new address[](9);
        uint256[] memory _values = new uint256[](9);
        bytes[] memory _calldatas = new bytes[](9);
        string[] memory _signatures = new string[](9);

        // Let USDCx pull the USDC we are about to wrap.
        _targets[0] = address(USDC);
        _calldatas[0] = abi.encodeWithSelector(IERC20.approve.selector, address(USDCx), WRAP_USDC);

        // Wrap it: a month of runway plus the pod margin.
        _targets[1] = address(USDCx);
        _calldatas[1] = abi.encodeWithSelector(IUSDCx.upgrade.selector, WRAP_USDCX);

        // Send the margin to the pod. It carries the old cohort through the overlap until the switch.
        _targets[2] = address(USDCx);
        _calldatas[2] = abi.encodeWithSelector(IUSDCx.transfer.selector, STREAM_POD, POD_MARGIN);

        // Point the master stream at the pod, $3.21M/yr.
        _targets[3] = address(SUPERFLUID);
        _calldatas[3] =
            abi.encodeWithSelector(CFAv1Forwarder.setFlowrate.selector, address(USDCx), STREAM_POD, MASTER_FLOW_RATE);

        // Refresh the autowrap allowance.
        _targets[4] = address(USDC);
        _calldatas[4] = abi.encodeWithSelector(IERC20.approve.selector, AUTOWRAPPER, AUTOWRAP_ALLOWANCE);

        // Committee 20% lump sum, USDC straight to each member.
        _targets[5] = address(USDC);
        _calldatas[5] = abi.encodeWithSelector(IERC20.transfer.selector, COLTRON, LUMP_CHAIR);
        _targets[6] = address(USDC);
        _calldatas[6] = abi.encodeWithSelector(IERC20.transfer.selector, SOVEREIGNSIGNAL, LUMP_MEMBER);
        _targets[7] = address(USDC);
        _calldatas[7] = abi.encodeWithSelector(IERC20.transfer.selector, AUSTINGRIFFITH, LUMP_MEMBER);
        _targets[8] = address(USDC);
        _calldatas[8] = abi.encodeWithSelector(IERC20.transfer.selector, ABDULLAHUMAR, LUMP_MEMBER);

        return (_targets, _values, _signatures, _calldatas, description);
    }

    function _afterExecution() public override {
        assertEq(SUPERFLUID.getFlowrate(address(USDCx), address(timelock), STREAM_POD), MASTER_FLOW_RATE);

        // The pod received its margin.
        assertApproxEqAbs(USDCx.balanceOf(STREAM_POD), podBalanceBefore + POD_MARGIN, 1000e18);

        // The timelock still holds the month it wrapped (minus what streamed out in the meantime).
        assertGt(USDCx.balanceOf(address(timelock)), timelockBalanceBefore);

        assertEq(USDC.allowance(address(timelock), AUTOWRAPPER), AUTOWRAP_ALLOWANCE);

        // Each committee member got their 20% lump sum.
        assertEq(USDC.balanceOf(COLTRON), coltronUsdcBefore + LUMP_CHAIR);
        assertEq(USDC.balanceOf(SOVEREIGNSIGNAL), svUsdcBefore + LUMP_MEMBER);
        assertEq(USDC.balanceOf(AUSTINGRIFFITH), agUsdcBefore + LUMP_MEMBER);
        assertEq(USDC.balanceOf(ABDULLAHUMAR), auUsdcBefore + LUMP_MEMBER);
        console2.log("master flow rate after:", uint256(int256(MASTER_FLOW_RATE)));
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-49";
    }
}
