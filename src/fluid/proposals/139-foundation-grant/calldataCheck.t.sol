// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

interface IFluidGovernorBravo {
    function castVote(uint256 proposalId, uint8 support) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function state(uint256 proposalId) external view returns (uint8);
}

interface IFluidToken {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

interface IFluidTimelock {
    function delay() external view returns (uint256);
    function executePayload(
        address target,
        string calldata signature,
        bytes calldata data
    )
        external
        returns (bytes memory);
}

interface IERC20Balance {
    function balanceOf(address account) external view returns (uint256);
}

interface IFluidPayload {
    function isProposalExecutable() external view returns (bool);
    function toggleExecutable(bool executable) external;
}

interface IFluidReserve {
    function owner() external view returns (address);
    function withdrawFunds(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address to,
        string calldata reason
    )
        external;
}

/// @notice Independent calldata reconstruction and full lifecycle simulation for FLUID IGP-139.
contract Proposal_FLUID_139_Test is CalldataComparison {
    IFluidGovernorBravo constant GOVERNOR = IFluidGovernorBravo(0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B);
    IFluidToken constant FLUID = IFluidToken(0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb);
    IFluidTimelock constant TIMELOCK = IFluidTimelock(0x2386DC45AdDed673317eF068992F19421B481F4c);
    IFluidReserve constant RESERVE = IFluidReserve(0x264786EF916af64a1DB19F513F24a3681734ce92);
    IERC20Balance constant STETH = IERC20Balance(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    IFluidPayload constant PAYLOAD_CONTRACT = IFluidPayload(0xe9941Bb0844160BdE0Cc19f7C0F0357D4Af78400);
    address constant PAYLOAD = address(PAYLOAD_CONTRACT);
    address constant TEAM_MULTISIG = 0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e;
    address constant FOUNDATION = 0xde0377eF25aD02dBcFbc87D632E46bf1972A0Dc3;
    address constant SIMULATED_VOTER = 0x0000000000000000000000000000000000000139;
    uint256 constant PROPOSAL_ID = 139;
    uint256 constant START_BLOCK = 25_834_838;
    uint256 constant END_BLOCK = 25_849_238;
    uint96 constant QUORUM_PLUS_ONE = 4_000_001 ether;
    uint256 constant GRANT_AMOUNT = 155 ether;

    uint256 reserveBalanceBefore;
    uint256 foundationBalanceBefore;

    function setUp() public {
        vm.createSelectFork("mainnet");
    }

    function test_liveCalldataAndFullLifecycle() public {
        _beforeProposal();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();
        _compareLiveCalldata(
            vm.readFile(string.concat(dirPath(), "/proposalCalldata.json")), targets, values, calldatas
        );

        assertEq(GOVERNOR.state(PROPOSAL_ID), 1, "proposal must be active");
        vm.mockCall(
            address(FLUID),
            abi.encodeWithSelector(IFluidToken.getPriorVotes.selector, SIMULATED_VOTER, START_BLOCK),
            abi.encode(QUORUM_PLUS_ONE)
        );
        vm.prank(SIMULATED_VOTER);
        GOVERNOR.castVote(PROPOSAL_ID, 1);

        vm.roll(END_BLOCK + 1);
        assertEq(GOVERNOR.state(PROPOSAL_ID), 4, "proposal must succeed after quorum");
        GOVERNOR.queue(PROPOSAL_ID);
        assertEq(GOVERNOR.state(PROPOSAL_ID), 5, "proposal must be queued");

        // Fluid payloads require the authorized team multisig to enable execution after the vote succeeds.
        assertFalse(PAYLOAD_CONTRACT.isProposalExecutable(), "payload starts execution-gated");
        vm.prank(TEAM_MULTISIG);
        PAYLOAD_CONTRACT.toggleExecutable(true);
        assertTrue(PAYLOAD_CONTRACT.isProposalExecutable(), "team multisig must enable payload execution");

        vm.warp(block.timestamp + TIMELOCK.delay() + 1);
        GOVERNOR.execute(PROPOSAL_ID);
        assertEq(GOVERNOR.state(PROPOSAL_ID), 7, "proposal must execute");

        _afterExecution();
    }

    function _beforeProposal() internal {
        assertEq(RESERVE.owner(), address(TIMELOCK), "timelock must own Fluid Reserve");
        reserveBalanceBefore = STETH.balanceOf(address(RESERVE));
        foundationBalanceBefore = STETH.balanceOf(FOUNDATION);
        assertGe(reserveBalanceBefore, GRANT_AMOUNT, "reserve must hold the grant amount");
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(TIMELOCK);
        values[0] = 0;
        calldatas[0] = abi.encode(PAYLOAD, "execute()", bytes(""));

        assertEq(IFluidTimelock.executePayload.selector, bytes4(keccak256("executePayload(address,string,bytes)")));
    }

    function _afterExecution() internal view {
        // stETH is share-accounted and may round a token transfer down by one wei.
        assertApproxEqAbs(
            reserveBalanceBefore - STETH.balanceOf(address(RESERVE)),
            GRANT_AMOUNT,
            1,
            "reserve must spend 155 stETH within share-rounding tolerance"
        );
        assertApproxEqAbs(
            STETH.balanceOf(FOUNDATION) - foundationBalanceBefore,
            GRANT_AMOUNT,
            1,
            "foundation must receive 155 stETH within share-rounding tolerance"
        );
    }

    function dirPath() public pure override returns (string memory) {
        return "src/fluid/proposals/139-foundation-grant";
    }
}
