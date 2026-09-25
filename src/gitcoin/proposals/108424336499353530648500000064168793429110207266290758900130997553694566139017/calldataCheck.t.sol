// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import {Test} from "@forge-std/src/Test.sol";
import {CalldataComparison} from "@contracts/base/CalldataComparison.sol";

interface IGitcoinGovernor {
    function hashProposal(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas, bytes32 descriptionHash)
        external
        pure
        returns (uint256);

    function state(uint256 proposalId) external view returns (uint8);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function timelock() external view returns (address);
    function token() external view returns (address);
    function proposalGuardian() external view returns (address);
    function __acceptAdmin() external;
}

interface IGitcoinTimelock {
    function delay() external view returns (uint256);
    function setPendingAdmin(address newPendingAdmin) external;
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function queueTransaction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 eta)
        external
        returns (bytes32);

    function executeTransaction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 eta)
        external
        payable
        returns (bytes memory);

    function queuedTransactions(bytes32 txHash) external view returns (bool);
}

contract Proposal_GTC_UpgradeGovernor_Test is Test, CalldataComparison {
    uint256 internal constant CREATION_BLOCK = 26_041_897;
    uint256 internal constant PROPOSAL_ID =
        108424336499353530648500000064168793429110207266290758900130997553694566139017;
    uint256 internal constant VOTING_START = 26_055_037;
    uint256 internal constant VOTING_END = 26_095_357;

    address internal constant GOVERNOR_ADDRESS = 0x9D4C63565D5618310271bF3F3c01b2954C1D1639;
    address internal constant TIMELOCK_ADDRESS = 0x57a8865cfB1eCEf7253c27da6B4BC3dAEE5Be518;
    address internal constant NEW_GOVERNOR_ADDRESS = 0xef41CbD211076E8b1901e214Bf751d404cf06638;
    address internal constant GTC_TOKEN = 0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F;

    IGitcoinGovernor internal constant GOVERNOR = IGitcoinGovernor(GOVERNOR_ADDRESS);
    IGitcoinTimelock internal constant TIMELOCK = IGitcoinTimelock(TIMELOCK_ADDRESS);
    IGitcoinGovernor internal constant NEW_GOVERNOR = IGitcoinGovernor(NEW_GOVERNOR_ADDRESS);

    address internal adminBefore;
    address internal pendingAdminBefore;
    address internal guardianBefore;

    function setUp() public {
        vm.createSelectFork({urlOrAlias: "mainnet", blockNumber: CREATION_BLOCK});
        vm.label(GOVERNOR_ADDRESS, "GTC Governor Bravo");
        vm.label(TIMELOCK_ADDRESS, "Gitcoin Timelock");
        vm.label(NEW_GOVERNOR_ADDRESS, "Gitcoin Governor Charlie");
        vm.label(GTC_TOKEN, "GTC");
    }

    function test_proposal() public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _generateCallData();
        string memory description = vm.readFile(string.concat(dirPath(), "/proposalDescription.md"));
        bytes32 descriptionHash = keccak256(bytes(description));

        uint256 computedProposalId = GOVERNOR.hashProposal(targets, values, calldatas, descriptionHash);
        assertEq(computedProposalId, PROPOSAL_ID, "proposal id is not bound to the live description and actions");
        assertEq(GOVERNOR.proposalSnapshot(PROPOSAL_ID), VOTING_START, "unexpected voting start");
        assertEq(GOVERNOR.proposalDeadline(PROPOSAL_ID), VOTING_END, "unexpected voting end");
        assertEq(GOVERNOR.state(PROPOSAL_ID), 0, "proposal is not Pending at its creation block");

        _beforeProposal();

        uint256 eta = block.timestamp + TIMELOCK.delay() + 1;
        bytes memory setPendingAdminData = abi.encode(NEW_GOVERNOR_ADDRESS);
        bytes memory acceptAdminData = bytes("");
        vm.prank(GOVERNOR_ADDRESS);
        bytes32 setPendingAdminTx = TIMELOCK.queueTransaction(
            TIMELOCK_ADDRESS, 0, "setPendingAdmin(address)", setPendingAdminData, eta
        );
        vm.prank(GOVERNOR_ADDRESS);
        bytes32 acceptAdminTx = TIMELOCK.queueTransaction(
            NEW_GOVERNOR_ADDRESS, 0, "__acceptAdmin()", acceptAdminData, eta
        );
        assertTrue(TIMELOCK.queuedTransactions(setPendingAdminTx), "first action was not queued");
        assertTrue(TIMELOCK.queuedTransactions(acceptAdminTx), "second action was not queued");

        vm.warp(eta + 1);
        vm.prank(GOVERNOR_ADDRESS);
        TIMELOCK.executeTransaction(TIMELOCK_ADDRESS, 0, "setPendingAdmin(address)", setPendingAdminData, eta);
        assertEq(TIMELOCK.pendingAdmin(), NEW_GOVERNOR_ADDRESS, "new Governor was not designated as pending admin");

        vm.prank(GOVERNOR_ADDRESS);
        TIMELOCK.executeTransaction(NEW_GOVERNOR_ADDRESS, 0, "__acceptAdmin()", acceptAdminData, eta);

        _afterExecution();
        _compareLiveCalldata(
            vm.readFile(string.concat(dirPath(), "/proposalCalldata.json")), targets, values, calldatas
        );
    }

    function _generateCallData()
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);

        targets[0] = TIMELOCK_ADDRESS;
        calldatas[0] = abi.encodeWithSelector(IGitcoinTimelock.setPendingAdmin.selector, NEW_GOVERNOR_ADDRESS);

        targets[1] = NEW_GOVERNOR_ADDRESS;
        calldatas[1] = abi.encodeWithSelector(IGitcoinGovernor.__acceptAdmin.selector);
    }

    function _beforeProposal() internal {
        adminBefore = TIMELOCK.admin();
        pendingAdminBefore = TIMELOCK.pendingAdmin();
        guardianBefore = NEW_GOVERNOR.proposalGuardian();

        assertEq(adminBefore, GOVERNOR_ADDRESS, "old Governor is not the Timelock admin");
        assertEq(pendingAdminBefore, address(0), "Timelock already has a pending admin");
        assertEq(address(NEW_GOVERNOR.timelock()), TIMELOCK_ADDRESS, "new Governor points to another Timelock");
        assertEq(NEW_GOVERNOR.token(), GTC_TOKEN, "new Governor is configured for another token");
        assertTrue(guardianBefore != address(0), "new Governor has no proposal guardian configured");
    }

    function _afterExecution() internal {
        assertEq(TIMELOCK.admin(), NEW_GOVERNOR_ADDRESS, "new Governor did not become Timelock admin");
        assertTrue(TIMELOCK.admin() != GOVERNOR_ADDRESS, "old Governor still controls the Timelock");
        assertEq(TIMELOCK.pendingAdmin(), address(0), "pending admin was not consumed");
        assertEq(address(NEW_GOVERNOR.timelock()), TIMELOCK_ADDRESS, "new Governor Timelock changed");
        assertEq(NEW_GOVERNOR.token(), GTC_TOKEN, "new Governor token changed");
        assertEq(NEW_GOVERNOR.proposalGuardian(), guardianBefore, "proposal guardian changed unexpectedly");
    }

    function dirPath() public pure override returns (string memory) {
        return "src/gitcoin/proposals/108424336499353530648500000064168793429110207266290758900130997553694566139017";
    }
}
