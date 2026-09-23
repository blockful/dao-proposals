# /// script
# requires-python = ">=3.13"
# dependencies = ["pytest", "eth-abi", "eth-utils", "eth-hash[pycryptodome]"]
# ///
# ─── How to run ───
# uv run --with pytest --with eth-abi --with eth-utils --with 'eth-hash[pycryptodome]' python -m pytest test_roles_replay.py
"""Regression boundaries for the event-based Roles policy comparison."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest
from eth_abi import encode
from eth_utils import keccak

import rolesReplay as replay


def test_unknown_event_fails_when_replay_cannot_model_it() -> None:
    # Given an event outside the supported ABI.
    logs = [{"topics": ["0x" + "ff" * 32], "data": "0x", "blockNumber": "0x1", "logIndex": "0x0"}]
    # When replayed, then incomplete reconstruction must fail.
    with pytest.raises(RuntimeError):
        replay.replay(logs)


def _log(block: int, index: int, address: str = replay.NEW, removed: bool = False) -> dict:
    return {"topics": [], "data": "0x", "blockNumber": hex(block), "logIndex": hex(index), "address": address, "removed": removed}


@pytest.mark.parametrize(
    "logs",
    [
        [_log(1, 0, removed=True)],
        [_log(1, 0), _log(1, 0)],
        [_log(1, 0, address=replay.OLD)],
    ],
    ids=["removed", "duplicate-position", "foreign-address"],
)
def test_replay_rejects_untrustworthy_log_input(logs: list[dict]) -> None:
    # Given reorged, duplicated or foreign logs, when replayed for the new Main, then input validation fails first.
    with pytest.raises(RuntimeError):
        replay.replay(logs, replay.NEW)


def test_assign_roles_rejects_mismatched_arrays() -> None:
    # Given an AssignRoles decode with more role keys than membership flags, when applied, then it fails closed.
    with pytest.raises(RuntimeError):
        replay.Roles().apply("AssignRoles", {"module": replay.POD, "roleKeys": [b"\x00" * 32, b"\x01" * 32], "memberOf": [True]})


def test_unknown_action_fails_when_state_machine_cannot_model_it() -> None:
    # Given a decoded action outside the explicitly handled set.
    state = replay.Roles()
    # When applied, then the state machine must fail closed.
    with pytest.raises(RuntimeError):
        state.apply("FuturePermissionEvent", {})


@pytest.mark.parametrize("operation,value,length,body", [(1, 0, 4, "deadbeef"), (0, 1, 4, "deadbeef"), (0, 0, 5, "deadbeef")])
def test_multisend_rejects_unmodelled_transaction_shape(operation: int, value: int, length: int, body: str) -> None:
    # Given a non-Call, nonzero-value or incomplete MultiSend item.
    item = f"{operation:02x}{replay.OLD[2:]}{value:064x}{length:064x}{body}"
    # When decoded, the policy replay must not silently treat it as a normal Call.
    with pytest.raises(replay.ReplayError):
        replay.decode_multisend("0x" + item)


def test_multisend_rejects_truncated_header() -> None:
    # Given an incomplete fixed-width MultiSend header.
    with pytest.raises(replay.ReplayError):
        replay.decode_multisend("0x00")


def test_old_modifier_unknown_admin_method_fails_closed() -> None:
    # Given an unrecognised call addressed to the modifier under review.
    with pytest.raises(replay.ReplayError):
        replay.apply_admin_calls(replay.Roles(), [(replay.OLD, bytes.fromhex("ffffffff"))], replay.OLD)


def test_function_key_survives_when_configuration_is_revoked() -> None:
    # Given a formerly allowed function.
    state = replay.Roles()
    args = {"roleKey": replay.MANAGER, "targetAddress": replay.OLD, "selector": "0x12345678", "options": 0}
    state.apply("AllowFunction", args)
    # When revoked.
    state.apply("RevokeFunction", args)
    # Then its storage key remains in the historical census.
    assert (replay.OLD, "0x12345678") in state.role(replay.MANAGER).get("functionKeys", set())


@pytest.mark.parametrize("operator", [1, 3, 22, 28, 29, 30])
def test_order_is_retained_when_operator_is_outside_pure_or(operator: int) -> None:
    # Given ordered logical branches, or an Or with a custom/allowance predicate.
    logical = operator if operator in (1, 3) else 2
    leaf_op = 16 if operator in (1, 3) else operator
    original = [(0, 0, logical, "0x"), (0, 1, leaf_op, "0x01"), (0, 1, leaf_op, "0x02")]
    reordered = [original[0], original[2], original[1]]
    # When canonicalized, then branch order must remain distinguishable.
    assert replay.canonical(original) != replay.canonical(reordered)


def test_order_is_retained_when_or_decoder_types_differ() -> None:
    # Given legal Dynamic/Calldata alternatives whose first child changes decoding.
    original = [(0, 0, 2, "0x"), (0, 2, 16, "0x01"), (0, 5, 5, "0x"), (2, 1, 16, "0x02")]
    reordered = [(0, 0, 2, "0x"), (0, 5, 5, "0x"), (0, 2, 16, "0x01"), (1, 1, 16, "0x02")]
    # When canonicalized, then heterogeneous decoder layouts must differ.
    assert replay.canonical(original) != replay.canonical(reordered)


def test_order_is_ignored_when_or_branches_are_pure_and_uniform() -> None:
    # Given a pure Or of identically typed equality predicates.
    original = [(0, 0, 2, "0x"), (0, 1, 16, "0x01"), (0, 1, 16, "0x02")]
    reordered = [original[0], original[2], original[1]]
    # When canonicalized, then permission-equivalent alternatives match.
    assert replay.canonical(original) == replay.canonical(reordered)


@pytest.mark.parametrize("param_type", [2, 4])
def test_pass_is_retained_when_trailing_leaf_needs_decoding(param_type: int) -> None:
    # Given a root Calldata Matches with a trailing Dynamic/Array Pass.
    original = [(0, 5, 5, "0x"), (0, 1, 16, "0x01"), (0, param_type, 0, "0x")]
    shortened = original[:-1]
    # When canonicalized, then decoder-sensitive tails must differ.
    assert replay.canonical(original) != replay.canonical(shortened)


@pytest.mark.parametrize("param_type", [3, 4, 5, 6])
def test_pass_is_retained_when_matches_is_nested(param_type: int) -> None:
    # Given a nested Matches whose layout may affect a later sibling.
    original = [(0, 5, 5, "0x"), (0, param_type, 5, "0x"), (0, 1, 16, "0x02"), (1, 1, 16, "0x01"), (1, 1, 0, "0x")]
    shortened = original[:-1]
    # When canonicalized, then nested structure must remain distinguishable.
    assert replay.canonical(original) != replay.canonical(shortened)


def test_pass_is_pruned_when_root_calldata_tail_is_static() -> None:
    # Given the observed USDC.transfer shape.
    original = [(0, 5, 5, "0x"), (0, 1, 16, "0x01"), (0, 1, 0, "0x")]
    shortened = original[:-1]
    # When canonicalized, then the inert static tail is equivalent.
    assert replay.canonical(original) == replay.canonical(shortened)


@pytest.mark.parametrize("mutation", ["options", "clearance", "snapshot", "unknown", "requested_block"])
def test_cli_fails_when_histories_are_incomparable(tmp_path: Path, mutation: str) -> None:
    # Given minimal wire-encoded histories and an empty update payload.
    (tmp_path / "expectedMultiSend.txt").write_text("0x", encoding="utf-8")
    old_types, new_types = ["bytes32", "address", "uint8"], ["bytes32", "address", "uint8"]
    old_args = [bytes.fromhex(replay.MANAGER[2:]), replay.OLD, 0]
    new_args = [bytes.fromhex(replay.MANAGER[2:]), replay.OLD, 1 if mutation == "options" else 0]
    new_sig = "AllowTarget(bytes32,address,uint8)"
    if mutation == "clearance":
        new_sig, new_types, new_args = "ScopeTarget(bytes32,address)", new_types[:-1], new_args[:-1]
    old_log = {"topics": ["0x" + keccak(text="AllowTarget(bytes32,address,uint8)").hex()], "data": "0x" + encode(old_types, old_args).hex(), "blockNumber": "0x1", "logIndex": "0x0"}
    new_log = {"topics": ["0x" + keccak(text=new_sig).hex()], "data": "0x" + encode(new_types, new_args).hex(), "blockNumber": "0x1", "logIndex": "0x0"}
    for name, log, address, end in [("old", old_log, replay.OLD, 1), ("new", new_log, replay.NEW, 2 if mutation == "snapshot" else 1)]:
        logs = [log]
        if mutation == "unknown" and name == "new":
            logs.append({"topics": ["0x" + "ff" * 32], "data": "0x", "blockNumber": "0x1", "logIndex": "0x1"})
        logs = [{**entry, "address": address} for entry in logs]  # real RPC logs carry their emitter
        (tmp_path / f"{name}.json").write_text(json.dumps({"address": address, "toBlock": end, "logs": logs}), encoding="utf-8")
    runner = "import rolesReplay as r; import sys; r.HERE=sys.argv[1]; requested=sys.argv[2:]; sys.argv=['rolesReplay.py','--logs',sys.argv[1]+'/old.json',sys.argv[1]+'/new.json']+requested; r.main()"
    # When the real CLI comparison runs.
    completed = subprocess.run([sys.executable, "-c", runner, str(tmp_path), *(["--block", "2"] if mutation == "requested_block" else [])], cwd=Path(replay.__file__).parent, capture_output=True, text=True, check=False)
    # Then incompleteness or target permission differences must return failure.
    assert completed.returncode != 0, completed.stdout


@pytest.mark.parametrize("event", ["SetAllowance", "ConsumeAllowance"])
def test_allowance_fails_when_comparison_does_not_model_consumption(event: str) -> None:
    # Given an allowance event requiring balance/time-dependent replay.
    args = {"allowanceKey": "0x" + "00" * 32, "balance": 0, "maxRefill": 0, "refill": 0, "period": 0, "timestamp": 0}
    # When applied, then the unsupported policy must fail closed.
    with pytest.raises(RuntimeError):
        replay.Roles().apply(event, args)


def test_cli_preserves_artifacts_when_no_write_is_requested(tmp_path: Path) -> None:
    # Given matching empty snapshots and an existing key-list artifact.
    (tmp_path / "expectedMultiSend.txt").write_text("0x", encoding="utf-8")
    marker = tmp_path / "roleStateKeys.json"
    marker.write_text("existing-artifact", encoding="utf-8")
    for label, address in (("old", replay.OLD), ("new", replay.NEW)):
        (tmp_path / f"{label}.json").write_text(json.dumps({"address": address, "toBlock": 25984900, "logs": []}), encoding="utf-8")
    runner = "import rolesReplay as r; import sys; r.HERE=sys.argv[1]; sys.argv=['rolesReplay.py','--logs',sys.argv[1]+'/old.json',sys.argv[1]+'/new.json','--no-write']; r.main()"
    # When the real CLI runs with --no-write.
    completed = subprocess.run([sys.executable, "-c", runner, str(tmp_path)], cwd=Path(replay.__file__).parent, capture_output=True, text=True, check=False)
    # Then the artifact is not replaced (empty histories fail the wiring gate, so the exit code is not asserted).
    assert "roleStateKeys.json not written" in completed.stdout, completed.stderr
    assert marker.read_text(encoding="utf-8") == "existing-artifact"


# ─── Verdict and wiring regressions (second adversarial pass) ────────────────────
SCOPE_FN = "ScopeFunction(bytes32,address,bytes4,(uint8,uint8,uint8,bytes)[],uint8)"
FN_TYPES = ["bytes32", "address", "bytes4", "(uint8,uint8,uint8,bytes)[]", "uint8"]
ROLE = bytes.fromhex(replay.MANAGER[2:])
EVIL = "0x000000000000000000000000000000000000dEaD"
ZERO = "0x" + "00" * 20


def _word(byte: int) -> bytes:
    return bytes([byte]) * 32


def _log(sig: str, types: list, args: list, index: int) -> dict:
    return {"topics": ["0x" + keccak(text=sig).hex()], "data": "0x" + encode(types, args).hex(), "blockNumber": "0x1", "logIndex": hex(index)}


def _indexed(sig: str, previous: str, current: str, index: int) -> dict:
    topic = lambda a: "0x" + "00" * 12 + a[2:].lower()
    return {"topics": ["0x" + keccak(text=sig).hex(), topic(previous), topic(current)], "data": "0x", "blockNumber": "0x1", "logIndex": hex(index)}


def _history(conditions: list, options: int = 0) -> list:
    return [_log("ScopeTarget(bytes32,address)", ["bytes32", "address"], [ROLE, replay.OLD], 0),
            _log(SCOPE_FN, FN_TYPES, [ROLE, replay.OLD, b"\x12\x34\x56\x78", conditions, options], 1)]


def _wiring(owner: str = replay.SAFE, extra: tuple = ()) -> list:
    multisend = bytes.fromhex(replay.MULTISEND[2:])
    assign = ("AssignRoles(address,bytes32[],bool[])", ["address", "bytes32[]", "bool[]"])
    unwrap = ("SetUnwrapAdapter(address,bytes4,address)", ["address", "bytes4", "address"])
    return [
        _log(*assign, [replay.POD, [ROLE], [True]], 10), _log(*assign, [replay.SUB, [ROLE], [True]], 11),
        _log("EnabledModule(address)", ["address"], [replay.POD], 12), _log("EnabledModule(address)", ["address"], [replay.SUB], 13),
        _log("SetDefaultRole(address,bytes32)", ["address", "bytes32"], [replay.SUB, ROLE], 14),
        _log(*unwrap, [replay.MS141, multisend, replay.ADAPTER], 15), _log(*unwrap, [replay.CO141, multisend, replay.ADAPTER], 16),
        _indexed("AvatarSet(address,address)", ZERO, replay.SAFE, 17), _indexed("TargetSet(address,address)", ZERO, replay.SAFE, 18),
        _indexed("OwnershipTransferred(address,address)", ZERO, owner, 19),
    ] + list(extra)


def _run(tmp_path: Path, old_logs: list, new_logs: list) -> int:
    (tmp_path / "expectedMultiSend.txt").write_text("0x", encoding="utf-8")
    for name, address, logs in (("old", replay.OLD, old_logs), ("new", replay.NEW, new_logs)):
        logs = [{**entry, "address": address} for entry in logs]  # real RPC logs carry their emitter
        (tmp_path / f"{name}.json").write_text(json.dumps({"address": address, "toBlock": 1, "logs": logs}), encoding="utf-8")
    runner = "import rolesReplay as r, sys; r.HERE=sys.argv[1]; sys.argv=['x','--logs',sys.argv[1]+'/old.json',sys.argv[1]+'/new.json','--no-write']; r.main()"
    return subprocess.run([sys.executable, "-c", runner, str(tmp_path)], cwd=Path(replay.__file__).parent, capture_output=True, text=True, check=False).returncode


BASE = [(0, 5, 5, b""), (0, 0, 2, b""), (1, 1, 16, _word(1)), (1, 1, 16, _word(2))]


@pytest.mark.parametrize("new_conditions,new_options,expected", [
    (BASE, 0, 0),                                             # identical
    ([BASE[0], BASE[1], BASE[3], BASE[2]], 0, 0),             # pure Or reorder only
    ([BASE[0], BASE[1], BASE[2], (1, 1, 16, _word(3))], 0, 1),  # widened alternative
    ([BASE[0], BASE[1], BASE[3], BASE[2]], 1, 1),             # reorder plus Send option
])
def test_cli_function_verdict(tmp_path: Path, new_conditions: list, new_options: int, expected: int) -> None:
    assert _run(tmp_path, _history(BASE), _history(new_conditions, new_options) + _wiring()) == expected


def test_cli_fails_when_function_only_on_one_side(tmp_path: Path) -> None:
    assert _run(tmp_path, _history(BASE)[:1], _history(BASE) + _wiring()) == 1


def test_canonical_keeps_order_when_stateful_operator_is_nested() -> None:
    # Integrity-valid: Calldata > Or > two Tuples, each with a WithinAllowance field.
    a = [(0, 5, 5, "0x"), (0, 0, 2, "0x"), (1, 3, 5, "0x"), (1, 3, 5, "0x"), (2, 1, 28, "0x" + "11" * 32), (3, 1, 28, "0x" + "22" * 32)]
    b = a[:4] + [(2, 1, 28, "0x" + "22" * 32), (3, 1, 28, "0x" + "11" * 32)]
    assert replay.canonical(a) != replay.canonical(b)


ROGUE = bytes.fromhex("41" * 32)


@pytest.mark.parametrize("extra", [
    (_log("AssignRoles(address,bytes32[],bool[])", ["address", "bytes32[]", "bool[]"], [replay.POD, [ROGUE], [True]], 20),
     _log("AllowTarget(bytes32,address,uint8)", ["bytes32", "address", "uint8"], [ROGUE, replay.OLD, 3], 21)),
    (_log("SetUnwrapAdapter(address,bytes4,address)", ["address", "bytes4", "address"], [replay.OLD, bytes.fromhex("a9059cbb"), EVIL], 20),),
    (_log("SetDefaultRole(address,bytes32)", ["address", "bytes32"], [replay.POD, ROLE], 20),),
    (_log("AssignRoles(address,bytes32[],bool[])", ["address", "bytes32[]", "bool[]"], [EVIL, [ROLE], [True]], 20),
     _log("EnabledModule(address)", ["address"], [EVIL], 21)),
    (_indexed("AvatarSet(address,address)", replay.SAFE, EVIL, 20),),
])
def test_cli_fails_on_rogue_new_main_wiring(tmp_path: Path, extra: tuple) -> None:
    assert _run(tmp_path, _history(BASE), _history(BASE) + _wiring(extra=extra)) == 1


def test_cli_blocks_until_owner_is_endowment_safe(tmp_path: Path) -> None:
    assert _run(tmp_path, _history(BASE), _history(BASE) + _wiring(owner="0xC01318baB7ee1f5ba734172bF7718b5DC6Ec90E1")) == 3


def test_order_is_retained_when_or_children_differ_in_operator() -> None:
    # Integrity-valid; Pass-first authorizes 4-byte calldata, EqualTo-first reverts reading the word.
    timelock = "0x" + "00" * 12 + "fe89cc7abb2c4183683ab71653c4cdc9b02d44b7"
    a = [(0, 5, 5, "0x"), (0, 0, 2, "0x"), (1, 1, 0, "0x"), (1, 1, 16, timelock)]
    b = a[:2] + [a[3], a[2]]
    assert replay.canonical(a) != replay.canonical(b)
