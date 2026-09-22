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
    # Then the comparison succeeds without replacing the artifact.
    assert completed.returncode == 0, completed.stderr
    assert marker.read_text(encoding="utf-8") == "existing-artifact"
