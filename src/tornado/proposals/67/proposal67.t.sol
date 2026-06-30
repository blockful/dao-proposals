// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Test } from "@forge-std/src/Test.sol";

interface IPayload {
    function governance() external view returns (address);
    function staking() external view returns (address);
    function nullifyBalance(address relayer) external;
}

interface IVault {
    function withdrawTorn(address account, uint256 amount) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title Tornado Cash Proposal 67 — malicious-proposal verification
/// @notice Proposal 67 is disguised as a relayer-fee / token-burn change. Its target
///         (the "payload") is a counterfeit Relayer Registry whose privileged roles
///         resolve to attacker-controlled vanity look-alike addresses. These tests
///         verify, on a pinned mainnet fork: (1) the spoofed addresses, (2) the
///         attacker's powers, and (3) that the DAO treasury is unreachable.
/// @dev    REQUIRES a non-censoring MAINNET_RPC_URL — several public RPCs block
///         Tornado Cash calls (OFAC). publicnode works; llamarpc/cloudflare do not.
abstract contract Proposal_TORN_67_Base is Test {
    IPayload internal constant PAYLOAD = IPayload(0x0D0BE561052d4cf419575E35dE4e60163a55185B);
    address internal constant ATTACKER_GOV = 0x5EFDa50f22D34F272c7077689d6ABc42F15E285f; // spoofed governance()
    address internal constant ATTACKER_STK = 0x2Fc93484614A34F7dBF98D7f7e997f6424e54a32; // spoofed staking()
    address internal constant REAL_GOV = 0x5efda50f22d34F262c29268506C5Fa42cB56A1Ce; // DAO governance / treasury
    // authority
    address internal constant REAL_STK = 0x2FC93484614a34f26F7970CBB94615bA109BB4bf;
    address internal constant VAULT = 0x2F50508a8a3D323B91336FA3eA6ae50E55f32185; // Governance Vault (treasury custody)
    IERC20 internal constant TORN = IERC20(0x77777FeDdddFfC19Ff86DB637967013e6C6A116C);
    address internal constant RELAYER = address(0xABCD);
    address internal constant SINK = address(0xBEEF);

    function setUp() public virtual {
        vm.createSelectFork("mainnet", 25_427_000);
    }

    function _try(address target, bytes memory data) internal returns (bool ok) {
        (ok,) = target.call(data);
    }
}

/// @notice CONTENT: the proposal does not do what it claims — it redirects the
///         registry's authorities to vanity look-alikes (shared 7-byte prefix).
contract Proposal_TORN_67_Content_Test is Proposal_TORN_67_Base {
    function _prefix(address a) internal pure returns (bytes7) {
        return bytes7(bytes20(a));
    }

    function test_governance_is_vanity_spoof() public view {
        assertEq(PAYLOAD.governance(), ATTACKER_GOV, "governance() should be the spoof");
        assertTrue(PAYLOAD.governance() != REAL_GOV, "must not be the real governance");
        assertEq(_prefix(PAYLOAD.governance()), _prefix(REAL_GOV), "must share the vanity prefix");
    }

    function test_staking_is_vanity_spoof() public view {
        assertEq(PAYLOAD.staking(), ATTACKER_STK, "staking() should be the spoof");
        assertTrue(PAYLOAD.staking() != REAL_STK, "must not be the real staking");
        assertEq(_prefix(PAYLOAD.staking()), _prefix(REAL_STK), "must share the vanity prefix");
    }
}

/// @notice POWERS: only the attacker can zero relayer stakes; the DAO is locked out.
contract Proposal_TORN_67_Powers_Test is Proposal_TORN_67_Base {
    function test_only_attacker_can_nullify_relayers() public {
        vm.prank(ATTACKER_GOV);
        PAYLOAD.nullifyBalance(RELAYER); // authorized -> no revert

        bool realGov = _tryNullify(REAL_GOV);
        bool random = _tryNullify(address(0xdead));
        assertFalse(realGov, "real governance must NOT be able to nullify");
        assertFalse(random, "random must NOT be able to nullify");
    }

    function _tryNullify(address caller) internal returns (bool ok) {
        vm.prank(caller);
        ok = _try(address(PAYLOAD), abi.encodeWithSignature("nullifyBalance(address)", RELAYER));
    }
}

/// @notice TREASURY: the attacker cannot move treasury assets by any path; only the
///         real governance proxy can (contrast drains the entire 7.32M TORN).
contract Proposal_TORN_67_Treasury_Test is Proposal_TORN_67_Base {
    function test_attacker_cannot_withdraw_vault() public {
        vm.prank(ATTACKER_GOV);
        bool ok = _try(VAULT, abi.encodeWithSignature("withdrawTorn(address,uint256)", SINK, uint256(2_000_000 ether)));
        assertFalse(ok, "attacker drained the vault");
    }

    function test_attacker_cannot_transferFrom_treasury() public {
        vm.prank(ATTACKER_GOV);
        bool a = _try(
            address(TORN),
            abi.encodeWithSignature("transferFrom(address,address,uint256)", VAULT, SINK, uint256(1 ether))
        );
        vm.prank(ATTACKER_GOV);
        bool b = _try(
            address(TORN),
            abi.encodeWithSignature("transferFrom(address,address,uint256)", REAL_GOV, SINK, uint256(1 ether))
        );
        assertFalse(a, "moved vault TORN");
        assertFalse(b, "moved governor TORN");
    }

    function test_attacker_cannot_upgrade_governance() public {
        vm.prank(ATTACKER_GOV);
        bool ok = _try(REAL_GOV, abi.encodeWithSignature("upgradeTo(address)", ATTACKER_GOV));
        assertFalse(ok, "attacker upgraded the governance proxy");
    }

    function test_realProxy_can_drain_entire_treasury() public {
        uint256 vaultBal = TORN.balanceOf(VAULT);
        vm.prank(REAL_GOV);
        IVault(VAULT).withdrawTorn(SINK, vaultBal);

        uint256 proxyBal = TORN.balanceOf(REAL_GOV);
        vm.prank(REAL_GOV);
        TORN.transfer(SINK, proxyBal);

        assertEq(TORN.balanceOf(SINK), vaultBal + proxyBal, "proxy could not drain");
        assertEq(TORN.balanceOf(VAULT), 0, "vault not emptied");
        assertEq(TORN.balanceOf(REAL_GOV), 0, "governor not emptied");
    }
}
