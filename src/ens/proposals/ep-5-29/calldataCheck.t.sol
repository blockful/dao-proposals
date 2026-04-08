// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { console2 } from "@forge-std/src/console2.sol";

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { IUSDC } from "@contracts/utils/interfaces/IUSDC.sol";
import { SuperToken } from "@contracts/utils/interfaces/IUSDCx.sol";
import { ISuperfluid } from "@contracts/utils/interfaces/ISuperfluid.sol";
import { BatchPlanner } from "@ens/interfaces/IHedgey.sol";
import { VotingTokenVestingPlans } from "@ens/interfaces/IHedgey.sol";

import { ENS_Governance } from "@ens/ens.t.sol";

/**
 * @title Proposal_ENS_EP_5_29_Test
 * @notice Calldata review for ENS EP 5.29 - Unruggable gateway funding
 * @dev This proposal sets up two streams:
 *      1. $1.2M USDC/year via Superfluid (4 transactions)
 *      2. 24,000 ENS over 2 years via Hedgey with 1-year cliff (2 transactions)
 */
contract Proposal_ENS_EP_5_29_Test is ENS_Governance {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 ENS = IERC20(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
    IERC20 USDCx = IERC20(0x1BA8603DA702602A8657980e825A6DAa03Dee93a);
    ISuperfluid superFluid = ISuperfluid(0xcfA132E353cB4E398080B9700609bb008eceB125);
    VotingTokenVestingPlans vestingLocker = VotingTokenVestingPlans(0x1bb64AF7FE05fc69c740609267d2AbE3e119Ef82);

    uint256 expectedUSDCtransfer = 1_200_000 * (10 ** 18);
    int96 USDCFlowRateBefore;
    int256 expectedUSDCFlowRate = 38_026_517_538_495_352;

    uint256 ENSbalanceBefore;
    uint256 expectedENStransfer = 24_000 * (10 ** 18);

    address receiver = 0x64Ca550F78d6Cc711B247319CC71A04A166707Ab;


    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 21_424_461, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x983110309620D911731Ac0932219af06091b6744; // brantly.eth
    }

    function _beforeProposal() public override {
        USDCFlowRateBefore = superFluid.getAccountFlowrate(address(USDCx), receiver);
        ENSbalanceBefore = ENS.balanceOf(receiver);
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        uint256 secondsInYear = 31_556_926;
        uint256 USDCInitialAllowance = 100_000 * 10 ** 6;
        uint256 USDCAmountPerSecond = expectedUSDCtransfer / secondsInYear;

        uint256 numTransactions = 6;

        targets = new address[](numTransactions);
        values = new uint256[](numTransactions);
        calldatas = new bytes[](numTransactions);
        signatures = new string[](numTransactions);

        // === Stream 1: Superfluid USDC stream ($1.2M/year) ===

        // Transaction 1: Approve USDCx to spend $100k USDC for initial wrapping
        targets[0] = address(USDC);
        calldatas[0] = abi.encodeWithSelector(IUSDC.approve.selector, address(USDCx), USDCInitialAllowance);
        values[0] = 0;
        signatures[0] = "";

        // Transaction 2: Upgrade $100k USDC to USDCx
        targets[1] = address(USDCx);
        calldatas[1] = abi.encodeWithSelector(SuperToken.upgrade.selector, USDCInitialAllowance);
        values[1] = 0;
        signatures[1] = "";

        // Transaction 3: Set Superfluid flow rate to receiver
        targets[2] = address(superFluid);
        calldatas[2] = abi.encodeWithSelector(ISuperfluid.setFlowrate.selector, address(USDCx), receiver, USDCAmountPerSecond);
        values[2] = 0;
        signatures[2] = "";

        // Transaction 4: Increase USDC allowance for Autowrap strategy
        targets[3] = address(USDC);
        calldatas[3] = abi.encodeWithSelector(
            IUSDC.increaseAllowance.selector, 0x1D65c6d3AD39d454Ea8F682c49aE7744706eA96d, 1_100_000 * 10 ** 6
        );
        values[3] = 0;
        signatures[3] = "";

        // === Stream 2: Hedgey ENS vesting (24k ENS, 2yr, 1yr cliff) ===

        BatchPlanner vesting = BatchPlanner(0x3466EB008EDD8d5052446293D1a7D212cb65C646);

        BatchPlanner.Plan[] memory plans = new BatchPlanner.Plan[](1);
        uint256 vestingStart = 1_735_065_935;
        uint256 cliff = 1_766_601_935;
        uint256 rate = 380_517_503_805_175;
        plans[0] = BatchPlanner.Plan(receiver, expectedENStransfer, vestingStart, cliff, rate);

        // Transaction 5: Approve ENS tokens for BatchPlanner
        targets[4] = address(ENS);
        calldatas[4] = abi.encodeWithSelector(ENS.approve.selector, address(vesting), expectedENStransfer);
        values[4] = 0;
        signatures[4] = "";

        // Transaction 6: Create Hedgey vesting plan
        targets[5] = address(vesting);
        calldatas[5] = abi.encodeWithSelector(
            BatchPlanner.batchVestingPlans.selector,
            vestingLocker,
            address(ENS),
            expectedENStransfer,
            plans,
            1,
            0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7,
            true,
            4
        );
        values[5] = 0;
        signatures[5] = "";

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        int96 USDCFlowRateAfter = superFluid.getAccountFlowrate(address(USDCx), receiver);
        assertEq(USDCFlowRateAfter - USDCFlowRateBefore, expectedUSDCFlowRate);

        // Before cliff - no ENS transferred
        assertEq(ENSbalanceBefore, ENS.balanceOf(receiver));

        // After 1 year cliff
        vm.warp(365 days);
        assertEq(ENSbalanceBefore, ENS.balanceOf(receiver));

        // Vesting locked
        vm.warp(365 days);
        assertEq(vestingLocker.lockedBalances(receiver, address(ENS)), expectedENStransfer);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-5-29";
    }
}
