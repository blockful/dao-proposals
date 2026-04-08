// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { ENS_Governance } from "@ens/ens.t.sol";
import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IUSDCx } from "@ens/interfaces/IUSDCx.sol";
import { CFAv1Forwarder } from "@ens/interfaces/ISuperfluidCFAv1Forwarder.sol";

contract Proposal_ENS_EP_6_13_Test is ENS_Governance {
    // Contract addresses
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDCx public constant USDCx = IUSDCx(0x1BA8603DA702602A8657980e825A6DAa03Dee93a);
    CFAv1Forwarder public constant SUPERFLUID = CFAv1Forwarder(0xcfA132E353cB4E398080B9700609bb008eceB125);
    
    // Flow parameters
    address public streamPod = 0xB162Bf7A7fD64eF32b787719335d06B2780e31D1;
    address public autowrapper = 0x1D65c6d3AD39d454Ea8F682c49aE7744706eA96d;
    
    // Amounts and flow rates
    uint256 public constant INITIAL_USDC_AMOUNT = 375_000_000_000; // 375,000 USDC (6 decimals)
    uint256 public constant UPGRADE_AMOUNT = 375_000_000_000_000_000_000_000; // 375,000 USDCx (18 decimals)
    int96 public constant NEW_FLOW_RATE = 142_599_440_769_357_573; // ~$4.5M/year
    uint256 public constant AUTOWRAP_ALLOWANCE = 6_375_000_000_000; // 6.375M USDC

    int96 currentFlowRate;
    uint256 currentUSDCxBalanceTimelock;
    uint256 currentUSDCxBalanceStreamPod;
    uint256 currentUSDCApproval;
    uint256 currentAutowrapAllowance;
    

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 22_784_697, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xe52C39327FF7576bAEc3DBFeF0787bd62dB6d726; // 5pence.eth
    }

    function _beforeProposal() public override {
        // Check initial flow rate (should be lower than new rate)
        currentFlowRate = SUPERFLUID.getFlowrate(address(USDCx), address(timelock), streamPod);
        assertLt(currentFlowRate, NEW_FLOW_RATE);
        console2.log("current flow rate USDCx from timelock -> streamPod:", currentFlowRate);
        
        // Check USDCx balance before upgrade
        currentUSDCxBalanceTimelock = USDCx.balanceOf(address(timelock));
        console2.log("current USDCx balance on timelock:", currentUSDCxBalanceTimelock/1e18);
        
        // current USDC approval for USDCx
        currentUSDCApproval = USDC.allowance(address(timelock), address(USDCx));
        console2.log("current USDC approval from timelock -> USDCx:", currentUSDCApproval/1e6);
        
        // current USDCx balance on streamPod
        currentUSDCxBalanceStreamPod = USDCx.balanceOf(address(streamPod));
        console2.log("current USDCx balance on streamPod:", currentUSDCxBalanceStreamPod/1e18);
        console2.log("timestamp:", block.timestamp);

        // current Autowrap allowance
        currentAutowrapAllowance = USDC.allowance(address(timelock), autowrapper);
        console2.log("current USDC approval timelock -> autowrapper:", currentAutowrapAllowance/1e6);
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
        description = getDescriptionFromMarkdown();

        // Transaction 1: Approve USDCx contract to spend USDC for upgrade
        address[] memory internalTargets = new address[](4);
        uint256[] memory internalValues = new uint256[](4);
        bytes[] memory internalCalldatas = new bytes[](4);
        string[] memory internalSignatures = new string[](4);

        // Transaction 1: Approve USDCx contract to spend USDC for upgrade
        internalTargets[0] = address(USDC);
        internalValues[0] = 0;
        internalSignatures[0] = "";
        internalCalldatas[0] = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(USDCx), // spender: USDCx contract
            INITIAL_USDC_AMOUNT // amount: 375,000 USDC
        );

        // Transaction 2: Upgrade USDC to USDCx
        internalTargets[1] = address(USDCx);
        internalValues[1] = 0;
        internalSignatures[1] = "";
        internalCalldatas[1] = abi.encodeWithSelector(
            IUSDCx.upgrade.selector,
            UPGRADE_AMOUNT // amount: 375,000 USDCx
        );

        // Transaction 3: Set new flow rate via Superfluid
        internalTargets[2] = address(SUPERFLUID);
        internalValues[2] = 0;
        internalSignatures[2] = "";
        internalCalldatas[2] = abi.encodeWithSelector(
            CFAv1Forwarder.setFlowrate.selector,
            address(USDCx), // token: USDCx
            streamPod, // stream pod
            NEW_FLOW_RATE // flowrate: ~$4.5M/year
        );

        // Transaction 4: Set autowrap allowance
        internalTargets[3] = address(USDC);
        internalValues[3] = 0;
        internalSignatures[3] = "";
        internalCalldatas[3] = abi.encodeWithSelector(
            IERC20.approve.selector,
            autowrapper, // spender: autowrapper
            AUTOWRAP_ALLOWANCE // amount: 6.375M USDC
        );

        return (internalTargets, internalValues, internalSignatures, internalCalldatas, description);
    }

    function _afterExecution() public override {
        // New flow rate
        int96 newFlowRate = SUPERFLUID.getFlowrate(address(USDCx), address(timelock), streamPod);
        console2.log("new flow rate USDCx from timelock -> streamPod:", newFlowRate);

        // Validate flowrate
        assertEq(newFlowRate, NEW_FLOW_RATE);
        
        // Check USDCx balance before upgrade
        uint256 newUSDCxBalanceTimelock = USDCx.balanceOf(address(timelock));
        console2.log("new USDCx balance on timelock:", newUSDCxBalanceTimelock/1e18);
        
        // Validate USDCx balance on timelock was increased
        assertGt(newUSDCxBalanceTimelock, currentUSDCxBalanceTimelock);
        
        // new USDC approval for USDCx
        uint256 newUSDCApproval = USDC.allowance(address(timelock), address(USDCx));
        console2.log("new USDC approval from timelock -> USDCx:", newUSDCApproval/1e6);
        
        uint256 newUSDCxBalanceStreamPod = USDCx.balanceOf(address(streamPod));
        console2.log("new USDCx balance on streamPod:", newUSDCxBalanceStreamPod/1e18);
        console2.log("timestamp:", block.timestamp);

        // new Autowrap allowance
        uint256 newAutowrapAllowance = USDC.allowance(address(timelock), autowrapper);
        console2.log("new USDC approval timelock -> autowrapper:", newAutowrapAllowance/1e6);
        
        // Validate USDC approval on autowrapper was set to $6.375M
        assertEq(newAutowrapAllowance, AUTOWRAP_ALLOWANCE);

    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true; // Proposal exists with the given ID
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-13";
    }
}

