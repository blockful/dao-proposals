#!/usr/bin/env python3
# /// script
# requires-python = ">=3.13"
# dependencies = ["eth-abi", "eth-utils", "eth-hash[pycryptodome]"]
# ///
# ─── How to run ───
# Install uv: curl -LsSf https://astral.sh/uv/install.sh | sh
# ETH_RPC_URL=<archive rpc> uv run rolesReplay.py
# uv run rolesReplay.py --logs logs-old-main.json logs-new-main.json
"""
Independent reconstruction of the MANAGER policy on the current and the redeployed
Endowment Roles Modifier, from their on-chain event histories.

    old Main   0x703806E61847984346d2D7DDd853049627e50A40   (Roles v2.1.0, created block 19,736,050)
    new Main   0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59   (Roles v2.1.1, created block 25,941,653)

The script replays every configuration event (ScopeTarget / AllowTarget / RevokeTarget /
ScopeFunction / AllowFunction / RevokeFunction / AssignRoles / SetDefaultRole /
EnabledModule / DisabledModule / SetUnwrapAdapter) as the
Roles Modifier applies them, then applies the Update #10 admin calls (the payload verified
in update10Payload.t.sol, `expectedMultiSend.txt`) on top of the old Main, and diffs the
result against the new Main.

Condition trees are compared byte for byte first, then with conservative normalization:
only pure Or alternatives with identical decoder type trees may be reordered; only
trailing Static Pass leaves directly under root Calldata Matches may be omitted.
Unknown events and allowance histories are unsupported and fail closed.

Usage:
    ETH_RPC_URL=<archive rpc> uv run rolesReplay.py --block 25984900
    uv run rolesReplay.py --logs old.json new.json              # matching toBlock required
    Add --no-write to print the comparison without writing snapshots or key lists.

Output: the diff report on stdout and `roleStateKeys.json` (the key lists consumed by
calldataCheck.t.sol for the in-fork storage comparison).
"""
from __future__ import annotations
import json, os, sys, time, urllib.request
from eth_abi import decode as abi_decode
from eth_utils import keccak, to_checksum_address as cs
from rolesSemantics import ReplayError, canonical

OLD = '0x703806E61847984346d2D7DDd853049627e50A40'
NEW = '0xa23BEBFD3628D6Dd7B0638c147db11d9B6FaBD59'
OLD_CREATED, NEW_CREATED = 19_736_050, 25_941_653
MANAGER = '0x4d414e4147455200000000000000000000000000000000000000000000000000'
HERE = os.path.dirname(os.path.abspath(__file__))

# ─── ABI (Roles v2.1.x events and admin functions) ──────────────────────────────
COND = '(uint8,uint8,uint8,bytes)[]'
EVENTS = {
    'AllowTarget(bytes32,address,uint8)': ('roleKey', 'targetAddress', 'options'),
    'ScopeTarget(bytes32,address)': ('roleKey', 'targetAddress'),
    'RevokeTarget(bytes32,address)': ('roleKey', 'targetAddress'),
    'AllowFunction(bytes32,address,bytes4,uint8)': ('roleKey', 'targetAddress', 'selector', 'options'),
    f'ScopeFunction(bytes32,address,bytes4,{COND},uint8)': ('roleKey', 'targetAddress', 'selector', 'conditions', 'options'),
    'RevokeFunction(bytes32,address,bytes4)': ('roleKey', 'targetAddress', 'selector'),
    'AssignRoles(address,bytes32[],bool[])': ('module', 'roleKeys', 'memberOf'),
    'SetDefaultRole(address,bytes32)': ('module', 'defaultRoleKey'),
    'EnabledModule(address)': ('module',),
    'DisabledModule(address)': ('module',),
    'SetUnwrapAdapter(address,bytes4,address)': ('to', 'selector', 'adapter'),
    'SetAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)': ('allowanceKey', 'balance', 'maxRefill', 'refill', 'period', 'timestamp'),
    'OwnershipTransferred(address,address)': ('previousOwner', 'newOwner'),
    'AvatarSet(address,address)': ('previousAvatar', 'newAvatar'),
    'TargetSet(address,address)': ('previousTarget', 'newTarget'),
    'RolesModSetup(address,address,address,address)': ('initiator', 'owner', 'avatar', 'target'),
    'Initialized(uint64)': ('version',),
    'ConsumeAllowance(bytes32,uint128,uint128)': ('allowanceKey', 'consumed', 'newBalance'),
    'ExecutionFromModuleSuccess(address)': ('module',),
    'ExecutionFromModuleFailure(address)': ('module',),
    'HashExecuted(bytes32)': ('hash',),
    'HashInvalidated(bytes32)': ('hash',),
}
# indexed parameters (topics) per event, as in the verified Roles v2.1.1 ABI
INDEXED = {
    'OwnershipTransferred': (0, 1), 'AvatarSet': (0, 1), 'TargetSet': (0, 1), 'RolesModSetup': (0, 1, 2),
    'ExecutionFromModuleSuccess': (0,), 'ExecutionFromModuleFailure': (0,),
}
FUNCS = {
    'scopeTarget(bytes32,address)': 'ScopeTarget', 'allowTarget(bytes32,address,uint8)': 'AllowTarget',
    'revokeTarget(bytes32,address)': 'RevokeTarget', 'allowFunction(bytes32,address,bytes4,uint8)': 'AllowFunction',
    f'scopeFunction(bytes32,address,bytes4,{COND},uint8)': 'ScopeFunction', 'revokeFunction(bytes32,address,bytes4)': 'RevokeFunction',
    'setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)': 'SetAllowance', 'assignRoles(address,bytes32[],bool[])': 'AssignRoles',
    'setDefaultRole(address,bytes32)': 'SetDefaultRole', 'enableModule(address)': 'EnabledModule',
    'disableModule(address,address)': 'DisabledModule', 'setTransactionUnwrapper(address,bytes4,address)': 'SetUnwrapAdapter',
}
def _types(sig): return sig[sig.index('(') + 1:-1]
def _split(types):
    out, depth, cur = [], 0, ''
    for ch in types:
        if ch == ',' and depth == 0: out.append(cur); cur = ''; continue
        depth += ch == '('; depth -= ch == ')'; cur += ch
    if cur: out.append(cur)
    return out
TOPIC = {'0x' + keccak(text=s).hex(): s for s in EVENTS}
SELECTOR = {'0x' + keccak(text=s).hex()[:8]: s for s in FUNCS}

def hx(b): return '0x' + b.hex() if isinstance(b, (bytes, bytearray)) else b

def decode_log(l):
    sig = TOPIC.get(l['topics'][0])
    if not sig: raise ReplayError('unknown event topic: ' + l['topics'][0])
    name = sig[:sig.index('(')]; names = EVENTS[sig]; types = _split(_types(sig)); idx = INDEXED.get(name, ())
    args, ti = {}, 1
    for i, (n, t) in enumerate(zip(names, types)):
        if i in idx: args[n] = abi_decode([t], bytes.fromhex(l['topics'][ti][2:]))[0]; ti += 1
    rest = [(n, t) for i, (n, t) in enumerate(zip(names, types)) if i not in idx]
    if rest:
        for (n, _), v in zip(rest, abi_decode([t for _, t in rest], bytes.fromhex(l['data'][2:]))): args[n] = v
    return name, args

# ─── State machine ───────────────────────────────────────────────────────────────
class Roles:
    def __init__(s):
        s.roles, s.members, s.default, s.modules, s.unwrappers, s.allowances = {}, {}, {}, set(), {}, {}
        s.owner = s.avatar = s.target = None
    def role(s, k): return s.roles.setdefault(hx(k), {'targets': {}, 'functions': {}, 'functionKeys': set()})
    def apply(s, name, a):
        if name in ('AllowFunction', 'ScopeFunction', 'RevokeFunction'):
            s.role(a['roleKey'])['functionKeys'].add((cs(a['targetAddress']), hx(a['selector'])))
        if name == 'AllowTarget': s.role(a['roleKey'])['targets'][cs(a['targetAddress'])] = ('Target', a['options'])
        elif name == 'ScopeTarget': s.role(a['roleKey'])['targets'][cs(a['targetAddress'])] = ('Function', 0)
        elif name == 'RevokeTarget': s.role(a['roleKey'])['targets'][cs(a['targetAddress'])] = ('None', 0)
        elif name == 'AllowFunction': s.role(a['roleKey'])['functions'][(cs(a['targetAddress']), hx(a['selector']))] = ('wildcard', a['options'], None)
        elif name == 'ScopeFunction':
            conds = [(c[0], c[1], c[2], hx(c[3])) for c in a['conditions']]
            s.role(a['roleKey'])['functions'][(cs(a['targetAddress']), hx(a['selector']))] = ('scoped', a['options'], conds)
        elif name == 'RevokeFunction': s.role(a['roleKey'])['functions'].pop((cs(a['targetAddress']), hx(a['selector'])), None)
        elif name == 'AssignRoles':
            for k, m in zip(a['roleKeys'], a['memberOf']):
                s.members.setdefault(hx(k), set()); (s.members[hx(k)].add if m else s.members[hx(k)].discard)(cs(a['module']))
        elif name == 'SetDefaultRole': s.default[cs(a['module'])] = hx(a['defaultRoleKey'])
        elif name == 'EnabledModule': s.modules.add(cs(a['module']))
        elif name == 'DisabledModule': s.modules.discard(cs(a['module']))
        elif name == 'SetUnwrapAdapter': s.unwrappers[(cs(a['to']), hx(a['selector']))] = cs(a['adapter'])
        elif name in ('SetAllowance', 'ConsumeAllowance'): raise ReplayError('allowance replay is outside this comparison: ' + name)
        elif name == 'OwnershipTransferred': s.owner = cs(a['newOwner'])
        elif name == 'AvatarSet': s.avatar = cs(a['newAvatar'])
        elif name == 'TargetSet': s.target = cs(a['newTarget'])
        elif name in ('RolesModSetup', 'Initialized', 'ExecutionFromModuleSuccess', 'ExecutionFromModuleFailure', 'HashExecuted', 'HashInvalidated'): pass
        else: raise ReplayError('unsupported replay action: ' + name)

def replay(logs):
    st, counts = Roles(), {}
    for l in sorted(logs, key=lambda l: (int(l['blockNumber'], 16), int(l['logIndex'], 16))):
        name, args = decode_log(l)
        counts[name] = counts.get(name, 0) + 1; st.apply(name, args)
    return st, counts

def decode_multisend(hexstr):
    b = bytes.fromhex(hexstr.strip()[2:]); i, txs = 0, []
    while i < len(b):
        if len(b) - i < 85: raise ReplayError('truncated MultiSend header')
        operation = b[i]
        value = int.from_bytes(b[i + 21:i + 53], 'big')
        length = int.from_bytes(b[i + 53:i + 85], 'big')
        if operation != 0 or value != 0: raise ReplayError('unsupported MultiSend operation or value')
        if len(b) - i - 85 < length: raise ReplayError('truncated MultiSend data')
        to = cs('0x' + b[i + 1:i + 21].hex())
        txs.append((to, b[i + 85:i + 85 + length]))
        i += 85 + length
    return txs

def apply_admin_calls(st, txs, module):
    applied, skipped = [], []
    for to, data in txs:
        sig = SELECTOR.get('0x' + data[:4].hex())
        if to != module: skipped.append((to, '0x' + data[:4].hex())); continue
        if sig is None: raise ReplayError('unknown admin selector on old Main: 0x' + data[:4].hex())
        name = sig[:sig.index('(')]; types = _split(_types(sig)); vals = abi_decode(types, data[4:])
        pnames = {'scopeTarget': ('roleKey', 'targetAddress'), 'allowTarget': ('roleKey', 'targetAddress', 'options'), 'revokeTarget': ('roleKey', 'targetAddress'),
                  'allowFunction': ('roleKey', 'targetAddress', 'selector', 'options'), 'scopeFunction': ('roleKey', 'targetAddress', 'selector', 'conditions', 'options'),
                  'revokeFunction': ('roleKey', 'targetAddress', 'selector'), 'setAllowance': ('allowanceKey', 'balance', 'maxRefill', 'refill', 'period', 'timestamp'),
                  'assignRoles': ('module', 'roleKeys', 'memberOf'), 'setDefaultRole': ('module', 'defaultRoleKey'), 'enableModule': ('module',),
                  'disableModule': ('prevModule', 'module'), 'setTransactionUnwrapper': ('to', 'selector', 'adapter')}[name]
        st.apply(FUNCS[sig], dict(zip(pnames, vals))); applied.append(name)
    return applied, skipped

# ─── Log fetching ────────────────────────────────────────────────────────────────
def fetch_logs(rpc, addr, bounds):
    frm, latest = bounds
    def call(m, p):
        req = urllib.request.Request(rpc, data=json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': m, 'params': p}).encode(), headers={'content-type': 'application/json'})
        for a in range(5):
            try:
                r = json.load(urllib.request.urlopen(req, timeout=120))
                if 'error' in r: raise RuntimeError(r['error'])
                return r['result']
            except (urllib.error.URLError, TimeoutError, RuntimeError) as e: err = e; time.sleep(2 * (a + 1))
        raise err
    if latest is None: latest = int(call('eth_blockNumber', []), 16)
    logs, b, chunk = [], frm, 5000
    while b <= latest:
        e = min(b + chunk - 1, latest); logs += call('eth_getLogs', [{'address': addr, 'fromBlock': hex(b), 'toBlock': hex(e)}]); b = e + 1
        print(f'  {addr[:10]} {b - frm:,}/{latest - frm:,} blocks, {len(logs)} logs', end='\r', file=sys.stderr)
    print(file=sys.stderr); return logs, latest

def fkey(t, sel): return '0x' + t[2:].lower() + sel[2:].lower() + '0' * 16

def main():
    requested_block = int(sys.argv[sys.argv.index('--block') + 1]) if '--block' in sys.argv else None
    write_outputs = '--no-write' not in sys.argv
    if '--logs' in sys.argv:
        i = sys.argv.index('--logs'); old_snapshot = json.load(open(sys.argv[i + 1])); new_snapshot = json.load(open(sys.argv[i + 2]))
        latest = old_snapshot.get('toBlock')
        if not latest or latest != new_snapshot.get('toBlock'): raise ReplayError('log snapshots require the same explicit toBlock')
        if requested_block is not None and latest != requested_block: raise ReplayError('log snapshot does not match requested block')
        if old_snapshot.get('address', '').lower() != OLD.lower() or new_snapshot.get('address', '').lower() != NEW.lower(): raise ReplayError('log snapshot address mismatch')
        old_logs, new_logs = old_snapshot['logs'], new_snapshot['logs']
        if any(int(l['blockNumber'], 16) > latest for l in old_logs + new_logs): raise ReplayError('log exceeds snapshot toBlock')
    else:
        rpc = os.environ.get('ETH_RPC_URL') or os.environ.get('MAINNET_RPC_URL') or sys.exit('set ETH_RPC_URL')
        old_logs, latest = fetch_logs(rpc, OLD, (OLD_CREATED, requested_block)); new_logs, _ = fetch_logs(rpc, NEW, (NEW_CREATED, latest))
        if write_outputs:
            json.dump({'address': OLD, 'toBlock': latest, 'logs': old_logs}, open(os.path.join(HERE, 'logs-old-main.json'), 'w')); json.dump({'address': NEW, 'toBlock': latest, 'logs': new_logs}, open(os.path.join(HERE, 'logs-new-main.json'), 'w'))
    print('SNAPSHOT BLOCK', latest)
    old, oc = replay(old_logs); new, nc = replay(new_logs)
    print('old Main events:', oc); print('new Main events:', nc)
    applied, skipped = apply_admin_calls(old, decode_multisend(open(os.path.join(HERE, 'expectedMultiSend.txt')).read()), OLD)
    print(f'\nUpdate #10 delta applied to old Main: {len(applied)} admin calls {sorted(set(applied))}; skipped (not Roles admin on old Main): {len(skipped)}')
    o, n = old.role(MANAGER), new.role(MANAGER)
    ot = {k: v for k, v in o['targets'].items() if v[0] != 'None'}; nt = {k: v for k, v in n['targets'].items() if v[0] != 'None'}
    print(f'\nTARGETS  old+delta {len(ot)}  new {len(nt)}')
    print('  only in old+delta:', sorted(set(ot) - set(nt))); print('  only in new      :', sorted(set(nt) - set(ot)))
    target_mismatch = [(k, ot[k], nt[k]) for k in sorted(set(ot) & set(nt)) if ot[k] != nt[k]]
    print('  clearance/options mismatch:', target_mismatch)
    of, nf = o['functions'], n['functions']
    print(f'\nFUNCTIONS  old+delta {len(of)}  new {len(nf)}')
    print('  only in old+delta:', sorted(set(of) - set(nf))); print('  only in new      :', sorted(set(nf) - set(of)))
    identical, order_only, trailing_only, mismatch = [], [], [], []
    for k in sorted(set(of) & set(nf)):
        a, b = of[k], nf[k]
        if a == b: identical.append(k)
        elif a[:2] == b[:2] and canonical(a[2], False) == canonical(b[2], False): order_only.append(k)
        elif a[:2] == b[:2] and canonical(a[2]) == canonical(b[2]): trailing_only.append(k)
        else: mismatch.append(k)
    print(f'  byte-identical: {len(identical)}   Or-alternatives reordered only: {len(order_only)}   trailing Pass pruned only: {len(trailing_only)}   MISMATCH: {len(mismatch)}')
    for k in order_only: print('    reordered  ', k)
    for k in trailing_only: print('    trailingPass', k, '\n      old+delta:', of[k][2], '\n      new      :', nf[k][2])
    for k in mismatch: print('    MISMATCH   ', k, '\n      old+delta:', of[k], '\n      new      :', nf[k])
    print('\nMEMBERS    old+delta', {k: sorted(v) for k, v in old.members.items()}, '\n           new      ', {k: sorted(v) for k, v in new.members.items()})
    print('MODULES    old+delta', sorted(old.modules), '\n           new      ', sorted(new.modules))
    print('DEFAULT    old+delta', old.default, '\n           new      ', new.default)
    print('UNWRAPPERS old      ', old.unwrappers, '\n           new      ', new.unwrappers)
    print('WIRING differences above are reported separately: superseded/new Sub membership, modules and default role; old/new MultiSend unwrappers. They are not MANAGER policy mismatches.')
    print('ALLOWANCES old', old.allowances, ' new', new.allowances)
    print('OTHER ROLES old', [k for k in old.roles if k != MANAGER], ' new', [k for k in new.roles if k != MANAGER])
    print('OWNER/AVATAR/TARGET old', (old.owner, old.avatar, old.target), '\n                    new', (new.owner, new.avatar, new.target))
    keys = {
        'snapshotBlock': latest,
        'targets': sorted(set(o['targets']) | set(n['targets'])),
        'functionKeys': sorted({fkey(*k) for k in o['functionKeys'] | n['functionKeys']}),
        'identical': sorted(fkey(*k) for k in identical), 'orderOnly': sorted(fkey(*k) for k in order_only), 'trailingPassOnly': sorted(fkey(*k) for k in trailing_only),
    }
    if write_outputs: json.dump(keys, open(os.path.join(HERE, 'roleStateKeys.json'), 'w'), indent=1)
    print(f"\nroleStateKeys.json {'written' if write_outputs else 'not written'}: {len(keys['targets'])} targets, {len(keys['functionKeys'])} function keys")
    sys.exit(1 if mismatch or target_mismatch or set(ot) ^ set(nt) or set(of) ^ set(nf) else 0)

if __name__ == '__main__': main()
