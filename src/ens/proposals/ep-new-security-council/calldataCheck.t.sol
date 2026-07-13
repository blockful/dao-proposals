// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { ENS_Governance } from "@ens/ens.t.sol";
import { ENSConstants } from "@ens/Constants.sol";
import { ITimelock } from "@ens/interfaces/ITimelock.sol";
import { ISecurityCouncil } from "@ens/interfaces/ISecurityCouncil.sol";
import { ISafe } from "@ens/interfaces/ISafe.sol";

/**
 * @title Proposal_ENS_New_Security_Council_Test
 * @notice Live review of "[Executable] Establishing a new Security Council", proposed by nick.eth.
 * @dev Single call granting PROPOSER_ROLE on the ENS timelock to the new SecurityCouncil contract.
 *      In this timelock PROPOSER_ROLE gates cancel(), so the grant is the veto power. The term runs
 *      until 16 July 2028. Replaces the defeated EP 6.48, whose council was owned by the previous
 *      term's Safe. This deployment is owned by the 5-of-8 Safe of the members elected in EP 6.50.
 */
contract Proposal_ENS_New_Security_Council_Test is ENS_Governance {
    // New council, same bytecode as the audited EP 6.48 deployment, owned by the elected Safe
    ISecurityCouncil constant securityCouncil = ISecurityCouncil(0x2acBf518b3759f6e1fA163294eda55bF1d0ae051);
    // Term 1 council, keeps its role until it self-expires on 2026-07-24
    address constant oldSecurityCouncil = 0xB8fA0cE3f91F41C5292D07475b445c35ddF63eE0;
    // Council from the defeated EP 6.48, must never get the role
    address constant defeatedCouncil = 0xDeDEdD439ecF711E61f5aeceF631579DBA2C65dB;
    // 5-of-8 Safe holding the members elected in EP 6.50
    address constant councilSafe = 0x7101B78638e34444F0a5AdE9e1149fbEeC029931;

    // Canonical Safe 1.4.1 singleton and CompatibilityFallbackHandler
    address constant SAFE_SINGLETON_141 = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    address constant SAFE_FALLBACK_HANDLER_141 = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;
    // Safe storage slots: singleton is slot 0, guard and fallback handler are at fixed hashed slots
    bytes32 constant GUARD_SLOT = keccak256("guard_manager.guard.address");
    bytes32 constant FALLBACK_HANDLER_SLOT = keccak256("fallback_manager.handler.address");

    // Deploy timestamp (2026-07-10) plus two years plus one week, 2028-07-16 19:49:11 UTC
    uint256 constant EXPECTED_EXPIRATION = 1_847_389_751;

    uint256 constant expectedProposalId =
        77_767_899_528_494_238_518_019_756_391_533_686_963_875_234_067_646_094_287_125_791_110_488_147_463_806;

    function _selectFork() public override {
        // Proposal creation block, from proposalCalldata.json
        vm.createSelectFork({ blockNumber: 25_524_727, urlOrAlias: "mainnet" });
    }

    function _proposer() public pure override returns (address) {
        return 0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5; // nick.eth
    }

    function _beforeProposal() public override {
        assertEq(proposalId, expectedProposalId);

        // Council is deployed and wired to the elected Safe and this timelock
        assertEq(securityCouncil.owner(), councilSafe, "council not owned by the elected Safe");
        assertEq(securityCouncil.timelock(), address(timelock), "council points to wrong timelock");
        assertEq(securityCouncil.expiration(), EXPECTED_EXPIRATION, "unexpected expiration");
        assertGt(securityCouncil.expiration(), block.timestamp, "council already expired");

        // The Safe is a vanilla 5-of-8: canonical 1.4.1 singleton and fallback handler, no
        // modules that could execute past the threshold, no guard, and every owner is an EOA
        ISafe safe = ISafe(councilSafe);
        assertEq(safe.getThreshold(), 5, "unexpected threshold");
        assertEq(safe.getOwners().length, 8, "unexpected owner count");
        assertEq(safe.VERSION(), "1.4.1", "unexpected Safe version");
        assertEq(
            address(uint160(uint256(vm.load(councilSafe, bytes32(0))))), SAFE_SINGLETON_141, "unexpected singleton"
        );
        assertEq(vm.load(councilSafe, GUARD_SLOT), bytes32(0), "Safe has a guard");
        assertEq(
            address(uint160(uint256(vm.load(councilSafe, FALLBACK_HANDLER_SLOT)))),
            SAFE_FALLBACK_HANDLER_141,
            "unexpected fallback handler"
        );
        (address[] memory modules,) = safe.getModulesPaginated(address(0x1), 10);
        assertEq(modules.length, 0, "Safe has modules");
        for (uint256 i = 0; i < safe.getOwners().length; i++) {
            assertEq(safe.getOwners()[i].code.length, 0, "Safe owner is a contract");
        }

        // New council has no role yet. Term 1 still holds it, this proposal does not revoke it.
        // The defeated EP 6.48 council never got it.
        assertFalse(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)), "new council already has role");
        assertTrue(timelock.hasRole(PROPOSER_ROLE, oldSecurityCouncil), "term 1 council lost its role");
        assertFalse(timelock.hasRole(PROPOSER_ROLE, defeatedCouncil), "defeated EP 6.48 council has role");

        // Without the role the veto reverts and the op stays pending
        bytes32 pendingId = _scheduleDummyOperation("new-security-council-before");
        assertTrue(timelock.isOperationPending(pendingId));
        vm.prank(councilSafe);
        vm.expectRevert(
            "AccessControl: account 0x2acbf518b3759f6e1fa163294eda55bf1d0ae051 is missing role "
            "0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1"
        );
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

        // Grant PROPOSER_ROLE, the timelock's cancel gate, to the new council
        targets[0] = ENSConstants.TIMELOCK;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(ITimelock.grantRole.selector, PROPOSER_ROLE, address(securityCouncil));

        description = getDescriptionFromMarkdown();

        return (targets, values, signatures, calldatas, description);
    }

    function _afterExecution() public override {
        // New council holds the role, the other councils are unchanged
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)), "new council missing role");
        assertTrue(timelock.hasRole(PROPOSER_ROLE, oldSecurityCouncil), "term 1 council role changed");
        assertFalse(timelock.hasRole(PROPOSER_ROLE, defeatedCouncil), "defeated council gained role");

        // The Safe can now cancel a pending timelock op through the council
        bytes32 pendingId = _scheduleDummyOperation("new-security-council-after");
        assertTrue(timelock.isOperationPending(pendingId));
        vm.prank(councilSafe);
        securityCouncil.veto(pendingId);
        assertFalse(timelock.isOperation(pendingId), "op not cancelled");

        // Only the Safe can veto through the council
        bytes32 otherId = _scheduleDummyOperation("new-security-council-stranger");
        vm.expectRevert("Ownable: caller is not the owner");
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
        return true;
    }

    function dirPath() public pure override returns (string memory) {
        return "src/ens/proposals/ep-new-security-council";
    }
}
