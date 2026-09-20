// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { CalldataComparison } from "@contracts/base/CalldataComparison.sol";

interface IFluidGovernorBravo {
    function castVote(uint256 proposalId, uint8 support) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function state(uint256 proposalId) external view returns (uint8);
    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );
}

interface IFluidToken {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

interface IFluidTimelock {
    function delay() external view returns (uint256);
    function executePayload(address target, string calldata signature, bytes calldata data)
        external
        returns (bytes memory);
}

interface IFluidPayload {
    function isProposalExecutable() external view returns (bool);
    function toggleExecutable(bool executable) external;
}

interface IERC20Balance {
    function balanceOf(address account) external view returns (uint256);
}

/// @notice Independent calldata reconstruction and full lifecycle simulation for FLUID IGP-140.
contract Proposal_FLUID_140_Test is CalldataComparison {
    IFluidGovernorBravo constant GOVERNOR = IFluidGovernorBravo(0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B);
    IFluidToken constant FLUID = IFluidToken(0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb);
    IFluidTimelock constant TIMELOCK = IFluidTimelock(0x2386DC45AdDed673317eF068992F19421B481F4c);
    IFluidPayload constant PAYLOAD_CONTRACT = IFluidPayload(0x5Aa925cCb417656dcC03D06Adb37088d0Dccb31B);
    IERC20Balance constant USDC = IERC20Balance(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Balance constant USDT = IERC20Balance(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    address constant TEAM_MULTISIG = 0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e;
    address constant FOUNDATION = 0xde0377eF25aD02dBcFbc87D632E46bf1972A0Dc3;
    address constant SIMULATED_VOTER = 0x0000000000000000000000000000000000000140;
    uint256 constant PROPOSAL_ID = 140;
    uint256 constant CREATION_BLOCK = 26_012_206;
    uint256 constant START_BLOCK = 26_019_406;
    uint256 constant END_BLOCK = 26_033_806;
    uint96 constant QUORUM_PLUS_ONE = 4_000_000_000_000_000_000_000_001;
    uint256 constant USDC_GRANT = 170_000e6;
    uint256 constant USDT_GRANT = 150_000e6;
    uint256 constant ETH_GRANT = 13 ether;

    uint256 usdcBefore;
    uint256 usdtBefore;
    uint256 ethBefore;

    function setUp() public {
        // Pin the fork to the proposal creation block. The test advances the fork explicitly into
        // the voting window instead of using the chain tip, so the pre-execution state remains stable.
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    /// @notice Anchor the manual derivation and committed fixture to the Governor's live actions.
    function test_fixtureAndDerivationMatchOnchainProposal() public view {
        (
            address[] memory liveTargets,
            uint256[] memory liveValues,
            string[] memory liveSignatures,
            bytes[] memory liveCalldatas
        ) = GOVERNOR.getActions(PROPOSAL_ID);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        assertEq(liveTargets.length, 1, "proposal 140 must hold exactly one action");
        assertEq(targets.length, liveTargets.length, "derived action count must match chain");
        assertEq(liveTargets[0], targets[0], "derived target must match chain");
        assertEq(liveValues[0], values[0], "derived value must match chain");
        assertEq(liveCalldatas[0], calldatas[0], "derived calldata must match chain");
        assertEq(liveSignatures[0], "executePayload(address,string,bytes)", "unexpected onchain signature");

        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        assertEq(vm.parseJsonUint(json, ".proposalId"), PROPOSAL_ID, "fixture proposalId must match");
        assertEq(vm.parseJsonAddress(json, ".executableCalls[0].target"), liveTargets[0], "fixture target must match chain");
        assertEq(vm.parseJsonUint(json, ".executableCalls[0].value"), liveValues[0], "fixture value must match chain");
        assertEq(vm.parseJsonBytes(json, ".executableCalls[0].calldata"), liveCalldatas[0], "fixture calldata must match chain");
        assertEq(vm.parseJsonString(json, ".executableCalls[0].signature"), liveSignatures[0], "fixture signature must match chain");
    }

    function test_liveCalldataAndFullLifecycle() public {
        _beforeProposal();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();
        _compareLiveCalldata(
            vm.readFile(string.concat(dirPath(), "/proposalCalldata.json")), targets, values, calldatas
        );

        vm.roll(START_BLOCK + 1);
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

        // Fluid payloads are execution-gated by the authorized team multisig.
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
        assertEq(PAYLOAD_CONTRACT.isProposalExecutable(), false, "payload must start execution-gated");
        usdcBefore = USDC.balanceOf(FOUNDATION);
        usdtBefore = USDT.balanceOf(FOUNDATION);
        ethBefore = FOUNDATION.balance;
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
        calldatas[0] = abi.encode(address(PAYLOAD_CONTRACT), "execute()", bytes(""));

        assertEq(
            IFluidTimelock.executePayload.selector,
            bytes4(keccak256("executePayload(address,string,bytes)")),
            "unexpected timelock selector"
        );
    }

    function _afterExecution() internal view {
        assertTrue(PAYLOAD_CONTRACT.isProposalExecutable(), "payload must remain executable after execution");
        assertEq(USDC.balanceOf(FOUNDATION) - usdcBefore, USDC_GRANT, "foundation must receive 170,000 USDC");
        assertEq(USDT.balanceOf(FOUNDATION) - usdtBefore, USDT_GRANT, "foundation must receive 150,000 USDT");
        assertEq(FOUNDATION.balance - ethBefore, ETH_GRANT, "foundation must receive 13 ETH");
    }

    function dirPath() public pure override returns (string memory) {
        return "src/fluid/proposals/140-weeth-eth-vault";
    }
}
