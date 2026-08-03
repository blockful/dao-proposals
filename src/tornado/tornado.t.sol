// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";

import { IERC20 } from "@contracts/utils/interfaces/IERC20.sol";
import { ITornadoGovernance } from "@tornado/interfaces/ITornadoGovernance.sol";
import { TornadoConstants } from "@tornado/Constants.sol";

/// @title Tornado_Base
/// @notice Shared scaffolding for Tornado Cash tests: addresses, fork, labels and a
///         helper to acquire voting power through the real lock flow.
abstract contract Tornado_Base is Test {
    ITornadoGovernance internal constant GOV = ITornadoGovernance(TornadoConstants.GOVERNANCE);
    IERC20 internal constant TORN = IERC20(TornadoConstants.TORN);

    function setUp() public virtual {
        _selectFork();
        vm.label(TornadoConstants.GOVERNANCE, "TornadoGovernance");
        vm.label(TornadoConstants.TORN, "TORN");
        vm.label(TornadoConstants.VAULT, "TornadoVault");
        vm.label(TornadoConstants.STAKING, "TornadoStaking");
    }

    /// @dev Selects the fork (chain + block) for the test.
    function _selectFork() public virtual;

    /// @dev Acquires `amount` voting power for `who` via the real lock flow
    ///      (deal TORN -> approve -> lockWithApproval). Returns the locked balance.
    function _lock(address who, uint256 amount) internal returns (uint256) {
        deal(TornadoConstants.TORN, who, amount);
        vm.startPrank(who);
        TORN.approve(TornadoConstants.GOVERNANCE, amount);
        GOV.lockWithApproval(amount);
        vm.stopPrank();
        return GOV.lockedBalance(who);
    }
}

/// @title Tornado_Governance
/// @notice Base for legitimate Tornado proposals. Runs the full custom-governor
///         lifecycle (lock -> propose -> castVote -> execute) with before/after hooks.
abstract contract Tornado_Governance is Tornado_Base {
    address public proposer;
    uint256 public proposalId;

    function setUp() public virtual override {
        super.setUp();
        proposer = makeAddr("torn-proposer");
    }

    function test_proposal() public {
        _beforeProposal();

        address target = _proposalTarget();

        // 1. Acquire voting power above quorum.
        _lock(proposer, GOV.QUORUM_VOTES() + 1000 ether);

        // 2. Propose (or pick up an already-submitted proposal).
        if (_isProposalSubmitted()) {
            proposalId = GOV.proposalCount();
        } else {
            vm.prank(proposer);
            proposalId = GOV.propose(target, _metadata());
        }

        // 3. Enter the voting window and vote FOR.
        vm.warp(block.timestamp + GOV.VOTING_DELAY() + 1);
        assertEq(GOV.state(proposalId), 1, "proposal not Active");
        vm.prank(proposer);
        GOV.castVote(proposalId, true);

        // 4. Warp past voting + execution delay, then execute.
        vm.warp(block.timestamp + GOV.VOTING_PERIOD() + GOV.EXECUTION_DELAY() + 1);
        assertEq(GOV.state(proposalId), 4, "proposal not AwaitingExecution");
        GOV.execute(proposalId);

        assertEq(GOV.state(proposalId), 5, "proposal not Executed");
        _afterExecution();
    }

    function _proposalTarget() internal virtual returns (address);
    function _metadata() internal view virtual returns (string memory);
    function _isProposalSubmitted() public view virtual returns (bool);
    function _beforeProposal() public virtual;
    function _afterExecution() public virtual;
}

/// @dev Minimal executable proposal payload for the lifecycle self-test.
contract MockProposal {
    event Executed();

    function executeProposal() external {
        emit Executed();
    }
}

/// @notice Self-test: proves the Tornado_Governance lifecycle works end-to-end
///         against live mainnet state with a benign proposal contract.
contract Tornado_Lifecycle_Test is Tornado_Governance {
    function _selectFork() public override {
        vm.createSelectFork("mainnet", 25_427_000);
    }

    function _proposalTarget() internal override returns (address) {
        return address(new MockProposal());
    }

    function _metadata() internal pure override returns (string memory) {
        return "Tornado lifecycle self-test";
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return false;
    }

    function _beforeProposal() public view override {
        assertGt(GOV.QUORUM_VOTES(), 0, "quorum unset");
    }

    function _afterExecution() public view override {
        assertEq(GOV.state(proposalId), 5, "proposal not Executed");
    }
}
