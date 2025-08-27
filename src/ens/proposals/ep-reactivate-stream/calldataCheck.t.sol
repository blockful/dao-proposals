// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IUSDCx } from "@ens/interfaces/IUSDCx.sol";
import { CFAv1Forwarder } from "@ens/interfaces/ISuperfluidCFAv1Forwarder.sol";

contract ProposalENSEPReactivateStreamDraftTest is ENS_Governance {
  // Contract addresses
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDCx public constant USDCx = IUSDCx(0x1BA8603DA702602A8657980e825A6DAa03Dee93a);
    CFAv1Forwarder public constant SUPERFLUID = CFAv1Forwarder(0xcfA132E353cB4E398080B9700609bb008eceB125);
    
    // Flow parameters
    address public streamPod = 0xB162Bf7A7fD64eF32b787719335d06B2780e31D1;
    address public autowrapper = 0x1D65c6d3AD39d454Ea8F682c49aE7744706eA96d;
    
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant USDCX_DECIMALS = 18;

    // Amounts and flow rates
    uint256 public constant USD_REFILLED = 500_000 * 10 ** USDC_DECIMALS; // 500,000 USDC (6 decimals)
    uint256 public constant UPGRADE_AMOUNT = USD_REFILLED * 10 ** (USDCX_DECIMALS - USDC_DECIMALS);
    uint256 public constant RETROACTIVE_PAYMENT = 400_000 * 10 ** USDCX_DECIMALS; // 400,000 USDCX (18 decimals)
    int96 public constant NEW_FLOW_RATE = 142_599_440_769_357_573; // ~$4.5M/year
    uint256 public constant AUTOWRAP_ALLOWANCE = 6_375_000_000_000; // 6.375M USDC

    int96 internal currentFlowRate;
    uint256 internal currentUSDCXBalanceTimelock;
    uint256 internal currentUSDCXBalanceStreamPod;
    uint256 internal currentUSDCApproval;
    uint256 internal currentAutowrapAllowance;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 23226582, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x534631Bcf33BDb069fB20A93d2fdb9e4D4dD42CF; // slobo.eth
    }

    function _beforeProposal() public override {
        //  Check initial flow rate (should be lower than new rate)
        currentFlowRate = SUPERFLUID.getFlowrate(address(USDCx), address(timelock), streamPod);
        assertEq(currentFlowRate, 0);
        
        // Check USDCx balance before upgrade
        currentUSDCXBalanceTimelock = USDCx.balanceOf(address(timelock));
        assertEq(currentUSDCXBalanceTimelock, 0);
        
        // current USDC approval for USDCx
        currentUSDCApproval = USDC.allowance(address(timelock), address(USDCx));
        assertEq(currentUSDCApproval, 0);
        
        // current USDCx balance on streamPod
        currentUSDCXBalanceStreamPod = USDCx.balanceOf(address(streamPod));
        assertEq(currentUSDCXBalanceStreamPod, 0);

        // current Autowrap allowance
        currentAutowrapAllowance = USDC.allowance(address(timelock), autowrapper);
        assertEq(currentAutowrapAllowance, AUTOWRAP_ALLOWANCE);
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
        uint256 numTransactions = 4;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // 1. Approve 500k USDC to USDCX contract for wrapping
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(USDCx),
            USD_REFILLED
        );
        values[0] = 0;
        signatures[0] = "";

        // 2. Wrap 500k USDC into USDCX
        targets[1] = address(USDCx);
        calldatas[1] = abi.encodeWithSelector(
            IUSDCx.upgrade.selector,
            UPGRADE_AMOUNT
        );
        values[1] = 0;
        signatures[1] = "";

        // 3. Send 400k USDCX to Stream Management Pod
        targets[2] = address(USDCx);
        calldatas[2] = abi.encodeWithSelector(
            IUSDCx.transfer.selector,
            streamPod,
            RETROACTIVE_PAYMENT
        );
        values[2] = 0;
        signatures[2] = "";

        // 4. Create stream from Timelock to Stream Management Pod for $4.5M/year
        targets[3] = address(SUPERFLUID);
        calldatas[3] = abi.encodeWithSelector(
            CFAv1Forwarder.setFlowrate.selector,
            address(USDCx),
            streamPod,
            NEW_FLOW_RATE
        );
        values[3] = 0;
        signatures[3] = "";

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // Check that the flow rate has been set correctly
        int96 newFlowRate = SUPERFLUID.getFlowrate(address(USDCx), address(timelock), streamPod);
        assertEq(newFlowRate, NEW_FLOW_RATE);
        console2.log("new flow rate USDCX from timelock -> streamPod:", newFlowRate);
        
        // Check that USDCx balance increased for Stream Management Pod (retroactive payment)
        uint256 newUSDCXBalanceStreamPod = USDCx.balanceOf(address(streamPod));
        assertGe(newUSDCXBalanceStreamPod, currentUSDCXBalanceStreamPod + RETROACTIVE_PAYMENT);
        console2.log("new USDCX balance on streamPod:", newUSDCXBalanceStreamPod / 10 ** USDCX_DECIMALS);
        
        // Check that Timelock USDCx balance has the remaining amount for streaming
        uint256 newUSDCXBalanceTimelock = USDCx.balanceOf(address(timelock));
        console2.log("new USDCX balance on timelock:", newUSDCXBalanceTimelock / 10 ** USDCX_DECIMALS);

        // Verify USDC approval was consumed
        uint256 newUSDCApproval = USDC.allowance(address(timelock), address(USDCx));
        assertEq(newUSDCApproval, 0); // Should be consumed after upgrade
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-reactivate-stream";
    }
}
