// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { ISecurityCouncil } from "@ens/interfaces/ISecurityCouncil.sol";

/**
 * @title Proposal_ENS_EP_6_48_Test
 * @notice ENS EP 6.48 — Renewal of the Security Council (Term 2).
 * @dev Grants PROPOSER_ROLE on the ENS timelock to the new SecurityCouncil contract. In this
 *      timelock PROPOSER_ROLE gates cancel(), so the grant renews the council's veto power for
 *      another two-year term. Single executable call.
 */
contract Proposal_ENS_EP_6_48_Test is ENS_Governance {
    // Term 2 council — gets PROPOSER_ROLE from this proposal
    ISecurityCouncil constant securityCouncil = ISecurityCouncil(0xDeDEdD439ecF711E61f5aeceF631579DBA2C65dB);
    // Term 1 council — keeps its role until it self-expires on 2026-07-24
    address constant oldSecurityCouncil = 0xB8fA0cE3f91F41C5292D07475b445c35ddF63eE0;
    // 4-of-8 Safe that owns the council
    address constant councilSafe = 0xaA5cD05f6B62C3af58AE9c4F3F7A2aCC2Cdc2Cc7;

    uint256 constant expectedProposalId =
        45_402_179_622_316_441_394_139_979_097_514_597_399_865_468_312_011_562_941_203_078_514_615_705_423_505;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_424_113, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0x809FA673fe2ab515FaA168259cB14E2BeDeBF68e; // avsa.eth
    }

    function _beforeProposal() public override {
        assertEq(proposalId, expectedProposalId);

        // Council is deployed and wired to the Safe and this timelock
        assertEq(securityCouncil.owner(), councilSafe, "council not owned by the Safe");
        assertEq(securityCouncil.timelock(), address(timelock), "council points to wrong timelock");
        assertGt(securityCouncil.expiration(), block.timestamp, "council already expired");

        // New council has no role yet; old one still holds it (this proposal does not revoke it)
        assertFalse(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)), "new council already has role");
        assertTrue(timelock.hasRole(PROPOSER_ROLE, oldSecurityCouncil), "old council lost its role");

        // Without the role the veto reverts and the op stays pending
        bytes32 pendingId = _scheduleDummyOperation("ep-6-48-before");
        assertTrue(timelock.isOperationPending(pendingId));
        vm.prank(councilSafe);
        vm.expectRevert();
        securityCouncil.veto(pendingId);
        assertTrue(timelock.isOperationPending(pendingId));
    }

    function _generateCallData()
        public
        override
        returns (address[] memory, uint256[] memory, string[] memory, bytes[] memory, string memory)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        signatures = new string[](1);

        // Grant PROPOSER_ROLE (the timelock's cancel gate) to the new council
        targets[0] = ENSConstants.TIMELOCK;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(ITimelock.grantRole.selector, PROPOSER_ROLE, address(securityCouncil));

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // New council holds the role; old council's is unchanged
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)), "new council missing role");
        assertTrue(timelock.hasRole(PROPOSER_ROLE, oldSecurityCouncil), "old council role changed");

        // Council can now veto: the Safe cancels a pending timelock op
        bytes32 pendingId = _scheduleDummyOperation("ep-6-48-after");
        assertTrue(timelock.isOperationPending(pendingId));
        vm.prank(councilSafe);
        securityCouncil.veto(pendingId);
        assertFalse(timelock.isOperation(pendingId), "op not cancelled");
    }

    // Schedule a no-op via the Governor (a proposer) to get a pending op to veto
    function _scheduleDummyOperation(string memory saltSeed) internal returns (bytes32 id) {
        address target = address(timelock);
        uint256 value = 0;
        bytes memory data = "";
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256(bytes(saltSeed));
        uint256 delay = timelock.getMinDelay(); // read before prank, else it consumes the prank

        vm.prank(ENSConstants.GOVERNOR);
        timelock.schedule(target, value, data, predecessor, salt, delay);

        id = timelock.hashOperation(target, value, data, predecessor, salt);
    }

    function _isProposalSubmitted() public pure override returns (bool) {
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-6-48";
    }
}
