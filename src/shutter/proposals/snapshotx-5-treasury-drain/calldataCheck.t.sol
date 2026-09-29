// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

// =====================================================================================
//  Shutter DAO 0x36 — Snapshot X proposal #5 "Snapshot X execution re-test"
//
//  FINDING: MALICIOUS. The description claims the treasury sends 1 SHU to the sub-DAO.
//  The on-chain execution payload instead DELEGATECALLs the treasury Safe into an
//  unverified contract (0x77B1…9fD0) that liquidates USDC, WETH, sUSDS and SHU and sends
//  the proceeds (ETH + USDS) to a fresh EOA (0xef79…Fbc0). The "1 SHU" transfer is a
//  decoy gated on block.number <= 26_116_766, which is BEFORE the proposal's earliest
//  execution block (26_117_102), so it can never fire on a real execution.
//
//  Fork-only. Executes nothing on-chain.
// =====================================================================================

import { Test } from "@forge-std/src/Test.sol";
import { console2 } from "@forge-std/src/console2.sol";

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";

enum Choice {
    Against,
    For,
    Abstain
}

enum ProposalStatus {
    VotingDelay,
    VotingPeriod,
    VotingPeriodAccepted,
    Accepted,
    Executed,
    Rejected,
    Cancelled
}

enum Operation {
    Call,
    DelegateCall
}

struct IndexedStrategy {
    uint8 index;
    bytes params;
}

struct MetaTransaction {
    address to;
    uint256 value;
    bytes data;
    Operation operation;
    uint256 salt;
}

interface ISpace {
    function owner() external view returns (address);
    function proposals(uint256 proposalId)
        external
        view
        returns (
            address author,
            uint32 startBlockNumber,
            address executionStrategy,
            uint32 minEndBlockNumber,
            uint32 maxEndBlockNumber,
            uint8 finalizationStatus,
            bytes32 executionPayloadHash,
            uint256 activeVotingStrategies
        );
    function vote(
        address voter,
        uint256 proposalId,
        Choice choice,
        IndexedStrategy[] calldata userVotingStrategies,
        string calldata metadataURI
    )
        external;
    function execute(uint256 proposalId, bytes calldata executionPayload) external;
    function cancel(uint256 proposalId) external;
    function getProposalStatus(uint256 proposalId) external view returns (uint8);
}

interface IAvatarExecutionStrategy {
    function target() external view returns (address);
    function quorum() external view returns (uint256);
}

interface IVotes {
    function delegate(address delegatee) external;
    function getVotes(address account) external view returns (uint256);
}

/// @dev The only external function of the unverified payload contract (selector 0x8a4068dd).
interface IDrainer {
    function transfer() external;
}

contract Proposal_Shutter_SnapshotX_5_Test is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   LIVE ADDRESSES
    //////////////////////////////////////////////////////////////////////////*/

    address internal constant SAFE = 0x36bD3044ab68f600f6d3e081056F34f2a58432c4;
    ISpace internal constant SPACE = ISpace(0x594EB60b35C4E91A06a5df988e0504f7463cB769);
    IAvatarExecutionStrategy internal constant MODULE =
        IAvatarExecutionStrategy(0x5716a3b2d988Bd7a2D95942ee8a175D27a75E7bB);
    address internal constant ETH_TX_AUTHENTICATOR = 0xBA06E6cCb877C332181A6867c05c8b746A21Aed1;
    address internal constant COUNCIL = 0x3ea731dAF66D6A7980549f90152CD9A761B9c0C0;

    address internal constant SHU = 0xe485E2f1bab389C08721B291f6b59780feC83Fd7;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;

    address internal constant SUBDAO = 0xBF1a121A3ddd82b34f15aaE3Fa1F53E4D29dBF7B;

    /// @dev Attack actors.
    address internal constant PROPOSER = 0x61F31C7B10ab421dD45aaC97813286A5Ed8aA880;
    address internal constant DRAINER = 0x77B19Bcb9BDad5bB6F9756d085084a1aa03b9fD0;
    address internal constant RECIPIENT = 0xef794BF5Aca9377DbC7cB0D398a85F58B738Fbc0;

    uint256 internal constant PROPOSAL_ID = 5;
    /// @dev Last block at which the drainer still sends the decoy 1 SHU (PUSH4 0x018e829e).
    uint256 internal constant DECOY_LAST_BLOCK = 26_116_766;
    /// @dev Salt used by the proposer in the on-chain payload.
    uint256 internal constant SALT = 1;

    uint256 internal constant FORK_BLOCK = 26_085_000;
    uint256 internal constant VOTER_STAKE = 35_000_000 ether;

    address internal voter;

    function setUp() public {
        vm.createSelectFork({ blockNumber: FORK_BLOCK, urlOrAlias: "mainnet" });
        voter = makeAddr("voter");

        vm.label(SAFE, "ShutterSafe");
        vm.label(address(SPACE), "SnapshotX_Space");
        vm.label(address(MODULE), "SnapshotX_Module");
        vm.label(COUNCIL, "SecurityCouncil");
        vm.label(PROPOSER, "Proposer");
        vm.label(DRAINER, "Drainer");
        vm.label(RECIPIENT, "Recipient");

        assertEq(MODULE.target(), SAFE, "module must execute on the treasury Safe");
        assertEq(SPACE.owner(), COUNCIL, "Space owner (veto) must be the Security Council");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALLDATA
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev What the proposal text says it does.
    function _describedPayload() internal pure returns (bytes memory) {
        MetaTransaction[] memory txs = new MetaTransaction[](1);
        txs[0] = MetaTransaction({
            to: SHU,
            value: 0,
            data: abi.encodeWithSelector(IERC20.transfer.selector, SUBDAO, uint256(1 ether)),
            operation: Operation.Call,
            salt: SALT
        });
        return abi.encode(txs);
    }

    /// @dev What the proposal actually commits to on-chain.
    function _actualPayload() internal pure returns (bytes memory) {
        MetaTransaction[] memory txs = new MetaTransaction[](1);
        txs[0] = MetaTransaction({
            to: DRAINER,
            value: 0,
            data: abi.encodeWithSelector(IDrainer.transfer.selector),
            operation: Operation.DelegateCall,
            salt: SALT
        });
        return abi.encode(txs);
    }

    function test_onchainProposalMatchesDrainerPayload() public view {
        (address author,, address strategy, uint32 minEnd,,, bytes32 payloadHash,) = SPACE.proposals(PROPOSAL_ID);

        assertEq(author, PROPOSER, "author");
        assertEq(strategy, address(MODULE), "execution strategy is the treasury module");
        assertEq(payloadHash, keccak256(_actualPayload()), "on-chain hash = DELEGATECALL into drainer");
        assertTrue(payloadHash != keccak256(_describedPayload()), "FINDING: payload does not match description");

        // The decoy 1-SHU branch expires before the proposal can ever be executed.
        assertLt(DECOY_LAST_BLOCK, minEnd, "decoy cutoff precedes earliest execution block");
        assertGt(DRAINER.code.length, 0, "drainer is deployed");
    }

    function test_proposerBoughtJustAboveThreshold() public view {
        uint256 votes = IVotes(SHU).getVotes(PROPOSER);
        assertGe(votes, 10_000_000 ether, "clears 10M proposal threshold");
        assertLt(votes, 11_000_000 ether, "bought barely above threshold");
        assertLt(votes, MODULE.quorum(), "cannot reach quorum alone");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   SIMULATION
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Votes proposal 5 through quorum with a staged stake and rolls past its end.
    function _passProposal() internal {
        deal(SHU, voter, VOTER_STAKE);
        vm.prank(voter);
        IVotes(SHU).delegate(voter);

        (, uint32 start,,, uint32 maxEnd,,,) = SPACE.proposals(PROPOSAL_ID);
        vm.roll(start);

        IndexedStrategy[] memory strategies = new IndexedStrategy[](1);
        strategies[0] = IndexedStrategy({ index: 0, params: "" });
        vm.prank(ETH_TX_AUTHENTICATOR);
        SPACE.vote(voter, PROPOSAL_ID, Choice.For, strategies, "");

        vm.roll(uint256(maxEnd) + 1);
        assertEq(SPACE.getProposalStatus(PROPOSAL_ID), uint8(ProposalStatus.Accepted), "Accepted");
    }

    function test_execution_drainsTreasury() public {
        uint256 usdcBefore = IERC20(USDC).balanceOf(SAFE);
        uint256 susdsBefore = IERC20(SUSDS).balanceOf(SAFE);
        uint256 shuBefore = IERC20(SHU).balanceOf(SAFE);
        uint256 subdaoBefore = IERC20(SHU).balanceOf(SUBDAO);
        assertGt(usdcBefore, 0);
        assertGt(susdsBefore, 0);

        _passProposal();
        SPACE.execute(PROPOSAL_ID, _actualPayload());

        assertEq(IERC20(USDC).balanceOf(SAFE), 0, "all USDC sold");
        assertEq(IERC20(WETH).balanceOf(SAFE), 0, "all WETH unwrapped");
        assertEq(IERC20(SUSDS).balanceOf(SAFE), 0, "all sUSDS redeemed");
        assertEq(SAFE.balance, 0, "all ETH sent out");
        assertEq(IERC20(SHU).balanceOf(SAFE), 0, "all SHU dumped");
        assertGt(shuBefore, 0);
        assertEq(IERC20(SHU).balanceOf(SUBDAO), subdaoBefore, "decoy 1 SHU never sent");
        assertGt(IERC20(USDS).balanceOf(RECIPIENT), 0, "USDS to attacker");
        assertGt(RECIPIENT.balance, 0, "ETH to attacker");

        console2.log("SHU left in Safe   :", IERC20(SHU).balanceOf(SAFE) / 1e18);
        console2.log("USDS to attacker   :", IERC20(USDS).balanceOf(RECIPIENT) / 1e18);
        console2.log("ETH to attacker    :", RECIPIENT.balance / 1e18);
    }

    function test_councilVeto_blocksDrain() public {
        _passProposal();
        uint256 usdcBefore = IERC20(USDC).balanceOf(SAFE);
        uint256 susdsBefore = IERC20(SUSDS).balanceOf(SAFE);

        vm.prank(COUNCIL);
        SPACE.cancel(PROPOSAL_ID);
        assertEq(SPACE.getProposalStatus(PROPOSAL_ID), uint8(ProposalStatus.Cancelled), "Cancelled");

        vm.expectRevert();
        SPACE.execute(PROPOSAL_ID, _actualPayload());

        assertEq(IERC20(USDC).balanceOf(SAFE), usdcBefore, "USDC safe");
        assertEq(IERC20(SUSDS).balanceOf(SAFE), susdsBefore, "sUSDS safe");
    }

    function test_councilVeto_worksNow() public {
        assertEq(SPACE.getProposalStatus(PROPOSAL_ID), uint8(ProposalStatus.VotingDelay), "still in voting delay");
        vm.prank(COUNCIL);
        SPACE.cancel(PROPOSAL_ID);
        assertEq(SPACE.getProposalStatus(PROPOSAL_ID), uint8(ProposalStatus.Cancelled), "Cancelled");
    }
}
