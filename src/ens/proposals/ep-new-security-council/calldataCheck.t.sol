// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { ISecurityCouncil } from "@ens/interfaces/ISecurityCouncil.sol";

/**
 * @title Proposal_ENS_New_Security_Council_Draft_Test
 * @notice Draft review — "[Executable] Establishing a new Security Council".
 * @dev Grants PROPOSER_ROLE on the ENS timelock to the SecurityCouncil contract elected in the
 *      EP 6.50 election. In this timelock PROPOSER_ROLE gates cancel(), so the grant hands the
 *      council its veto power for a two-year term (expires 16 July 2028). Single executable call.
 *      Replaces the defeated EP 6.48, whose council was owned by the previous term's Safe; this
 *      deployment is owned by the 5-of-8 Safe of the newly elected members.
 */
contract Proposal_ENS_New_Security_Council_Draft_Test is ENS_Governance {
    // New council — same bytecode as the audited EP 6.48 deployment, owned by the elected Safe
    ISecurityCouncil constant securityCouncil = ISecurityCouncil(0x2acBf518b3759f6e1fA163294eda55bF1d0ae051);
    // Term 1 council — keeps its role until it self-expires on 2026-07-24
    address constant oldSecurityCouncil = 0xB8fA0cE3f91F41C5292D07475b445c35ddF63eE0;
    // EP 6.48's council (defeated) — must never have gotten the role
    address constant defeatedCouncil = 0xDeDEdD439ecF711E61f5aeceF631579DBA2C65dB;
    // 5-of-8 Safe holding the members elected in EP 6.50
    address constant councilSafe = 0x7101B78638e34444F0a5AdE9e1149fbEeC029931;

    // Deploy timestamp (2026-07-16) + two years + one week
    uint256 constant EXPECTED_EXPIRATION = 1_847_389_751;

    function _selectFork() public override {
        vm.createSelectFork({ blockNumber: 25_524_404, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth, the draft author
    }

    function _beforeProposal() public override {
        // Council is deployed and wired to the elected Safe and this timelock
        assertEq(securityCouncil.owner(), councilSafe, "council not owned by the elected Safe");
        assertEq(securityCouncil.timelock(), address(timelock), "council points to wrong timelock");
        assertEq(securityCouncil.expiration(), EXPECTED_EXPIRATION, "unexpected expiration");
        assertGt(securityCouncil.expiration(), block.timestamp, "council already expired");

        // New council has no role yet; term 1 still holds it (this proposal does not revoke it);
        // the defeated EP 6.48 council never got it
        assertFalse(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)), "new council already has role");
        assertTrue(timelock.hasRole(PROPOSER_ROLE, oldSecurityCouncil), "term 1 council lost its role");
        assertFalse(timelock.hasRole(PROPOSER_ROLE, defeatedCouncil), "defeated EP 6.48 council has role");

        // Without the role the veto reverts and the op stays pending
        bytes32 pendingId = _scheduleDummyOperation("new-security-council-before");
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
        // New council holds the role; the other councils' state is unchanged
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)), "new council missing role");
        assertTrue(timelock.hasRole(PROPOSER_ROLE, oldSecurityCouncil), "term 1 council role changed");
        assertFalse(timelock.hasRole(PROPOSER_ROLE, defeatedCouncil), "defeated council gained role");

        // Council can now veto: the Safe cancels a pending timelock op
        bytes32 pendingId = _scheduleDummyOperation("new-security-council-after");
        assertTrue(timelock.isOperationPending(pendingId));
        vm.prank(councilSafe);
        securityCouncil.veto(pendingId);
        assertFalse(timelock.isOperation(pendingId), "op not cancelled");

        // Only the Safe can veto through the council
        bytes32 otherId = _scheduleDummyOperation("new-security-council-stranger");
        vm.expectRevert();
        securityCouncil.veto(otherId);
        assertTrue(timelock.isOperationPending(otherId), "stranger vetoed through the council");
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
        return false; // draft — not yet on-chain
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-new-security-council";
    }
}
