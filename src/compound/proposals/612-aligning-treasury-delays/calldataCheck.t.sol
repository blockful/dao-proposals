// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Compound_Governance } from "@compound/compound.t.sol";

interface ITreasuryEscrow {
    function expiration() external view returns (uint40);
    function cooldown() external view returns (uint40);
    function setWithdrawExpiration(uint40 newExpiration) external;
    function setWithdrawCooldown(uint40 newCooldown) external;
}

interface ITreasuryTimelock {
    function getMinDelay() external view returns (uint256);
    function getTimestamp(bytes32 id) external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;
    function updateDelay(uint256 newDelay) external;
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);
}

/// @notice Independent reconstruction of Compound proposal 612 from its specification and typed interfaces.
contract Proposal_COMP_612_Test is Compound_Governance {
    ITreasuryEscrow internal constant TREASURY_ESCROW =
        ITreasuryEscrow(0xDcB34b56842F853A69E86De5A0c22c49d97C130C);
    ITreasuryTimelock internal constant TREASURY_TIMELOCK =
        ITreasuryTimelock(0xefeD08b791423C7D7937507Cf840E86a7ddC11c1);

    uint256 internal constant PROPOSAL_ID = 612;
    uint256 internal constant CREATION_BLOCK = 26_104_446;
    uint256 internal constant VOTE_START = 26_117_586;
    uint256 internal constant VOTE_END = 26_137_296;
    address internal constant TEST_VOTER = address(0x612);

    uint256 internal constant INITIAL_EXPIRATION = 7 days;
    uint256 internal constant INITIAL_COOLDOWN = 2 days;
    uint256 internal constant NEW_EXPIRATION = 17 days;
    uint256 internal constant NEW_COOLDOWN = 10 days;

    bytes32 internal constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 internal constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 internal constant SCHEDULE_SALT =
        0x703a0be5ed4c07d8ca94f71da77bd59768fc6588d87567765ac518e895705aaa;
    bytes32 internal constant EXPECTED_OPERATION_ID =
        0x953db1c078de556930197fab4266b633d0b7fd28477d9028de81a438e6c6214d;

    function setUp() public {
        vm.createSelectFork({ blockNumber: CREATION_BLOCK, urlOrAlias: "mainnet" });
    }

    function test_liveProposalExistsOnchain() public view {
        uint8 proposalState = GOVERNOR.state(PROPOSAL_ID);
        assertTrue(
            proposalState == 0 || proposalState == 1 || proposalState == 4 || proposalState == 5 || proposalState == 7,
            "proposal 612 is not executable"
        );
    }

    function test_fixtureMatchesOnchainProposal() public {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        string memory json = vm.readFile(string.concat(dirPath(), "/proposalCalldata.json"));
        assertEq(vm.parseJsonUint(json, ".proposalId"), PROPOSAL_ID);
        _compareLiveCalldata(json, liveTargets, liveValues, liveCalldatas);
    }

    function test_manuallyDerivedCalldataMatchesOnchainProposal() public view {
        (address[] memory liveTargets, uint256[] memory liveValues, bytes[] memory liveCalldatas,) =
            GOVERNOR.proposalDetails(PROPOSAL_ID);
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();

        assertEq(liveTargets.length, 5, "unexpected live call count");
        assertEq(liveValues.length, targets.length, "live values length mismatch");
        assertEq(liveCalldatas.length, targets.length, "live calldata length mismatch");
        assertEq(values.length, targets.length, "derived values length mismatch");
        assertEq(calldatas.length, targets.length, "derived calldata length mismatch");
        for (uint256 i; i < targets.length; ++i) {
            assertEq(liveTargets[i], targets[i], "target mismatch");
            assertEq(liveValues[i], values[i], "value mismatch");
            assertEq(liveCalldatas[i], calldatas[i], "calldata mismatch");
        }
    }


    function test_fullLifecycleAppliesTreasuryDelayControls() public {
        _beforeProposal();
        vm.roll(VOTE_START + 1);
        _executeLiveProposal(PROPOSAL_ID, VOTE_START, VOTE_END, TEST_VOTER);
        _afterExecution();
    }


    function _beforeProposal() internal view {
        assertEq(TREASURY_ESCROW.expiration(), INITIAL_EXPIRATION, "unexpected escrow expiration");
        assertEq(TREASURY_ESCROW.cooldown(), INITIAL_COOLDOWN, "unexpected escrow cooldown");
        assertFalse(
            TREASURY_TIMELOCK.hasRole(EXECUTOR_ROLE, address(TIMELOCK)), "governor timelock already has executor role"
        );
        assertFalse(
            TREASURY_TIMELOCK.hasRole(CANCELLER_ROLE, address(TIMELOCK)), "governor timelock already has canceller role"
        );
        assertEq(TREASURY_TIMELOCK.getMinDelay(), INITIAL_COOLDOWN, "unexpected treasury timelock delay");
        assertEq(_scheduledOperationId(), EXPECTED_OPERATION_ID, "unexpected scheduled operation id");
        assertEq(TREASURY_TIMELOCK.getTimestamp(EXPECTED_OPERATION_ID), 0, "operation already scheduled");
    }

    function _afterExecution() internal view {
        assertEq(TREASURY_ESCROW.expiration(), NEW_EXPIRATION, "escrow expiration was not updated");
        assertEq(TREASURY_ESCROW.cooldown(), NEW_COOLDOWN, "escrow cooldown was not updated");
        assertTrue(
            TREASURY_TIMELOCK.hasRole(EXECUTOR_ROLE, address(TIMELOCK)), "governor timelock executor role was not granted"
        );
        assertTrue(
            TREASURY_TIMELOCK.hasRole(CANCELLER_ROLE, address(TIMELOCK)), "governor timelock canceller role was not granted"
        );
        assertEq(TREASURY_TIMELOCK.getMinDelay(), INITIAL_COOLDOWN, "scheduled delay changed immediately");
        assertGt(
            TREASURY_TIMELOCK.getTimestamp(EXPECTED_OPERATION_ID), block.timestamp,
            "delay update operation was not scheduled"
        );
    }

    function _scheduledOperationId() internal pure returns (bytes32) {
        bytes memory updateDelayCall =
            abi.encodeWithSelector(ITreasuryTimelock.updateDelay.selector, uint256(NEW_COOLDOWN));
        return keccak256(
            abi.encode(address(TREASURY_TIMELOCK), uint256(0), updateDelayCall, bytes32(0), SCHEDULE_SALT)
        );
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](5);
        values = new uint256[](5);
        calldatas = new bytes[](5);

        targets[0] = address(TREASURY_ESCROW);
        calldatas[0] = abi.encodeWithSelector(ITreasuryEscrow.setWithdrawExpiration.selector, uint40(NEW_EXPIRATION));

        targets[1] = address(TREASURY_ESCROW);
        calldatas[1] = abi.encodeWithSelector(ITreasuryEscrow.setWithdrawCooldown.selector, uint40(NEW_COOLDOWN));

        targets[2] = address(TREASURY_TIMELOCK);
        calldatas[2] = abi.encodeWithSelector(
            ITreasuryTimelock.grantRole.selector, EXECUTOR_ROLE, address(TIMELOCK)
        );

        targets[3] = address(TREASURY_TIMELOCK);
        calldatas[3] = abi.encodeWithSelector(
            ITreasuryTimelock.grantRole.selector, CANCELLER_ROLE, address(TIMELOCK)
        );

        targets[4] = address(TREASURY_TIMELOCK);
        calldatas[4] = abi.encodeWithSelector(
            ITreasuryTimelock.schedule.selector,
            address(TREASURY_TIMELOCK),
            uint256(0),
            abi.encodeWithSelector(ITreasuryTimelock.updateDelay.selector, uint256(NEW_COOLDOWN)),
            bytes32(0),
            SCHEDULE_SALT,
            INITIAL_COOLDOWN
        );
    }

    function dirPath() public pure override returns (string memory) {
        return "src/compound/proposals/612-aligning-treasury-delays";
    }
}
