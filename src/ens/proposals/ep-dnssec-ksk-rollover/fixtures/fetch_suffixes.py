#!/usr/bin/env python3
"""Usage: python3 -I fixtures/fetch_suffixes.py <RPC_URL> > fixtures/suffixes.json"""

import json
import subprocess
import sys
import urllib.request

SUFFIX_LIST = "0x823BDa9cA8c47d072376eCD595530c8fb2fAa3ED"
DEPLOY_BLOCK = 19_027_537
STEP = 500_000


def rpc(url, method, params):
    req = urllib.request.Request(
        url,
        data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
        headers={"content-type": "application/json", "user-agent": "dao-proposals/fetch_suffixes"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        body = json.load(r)
    if "error" in body:
        raise RuntimeError(body["error"])
    return body["result"]


def labels(name):
    out, i = [], 0
    while name[i]:
        out.append(name[i + 1 : i + 1 + name[i]].decode())
        i += 1 + name[i]
    return out


def main():
    url = sys.argv[1]
    topic = subprocess.check_output(["cast", "keccak", "SuffixAdded(bytes)"], text=True).strip()
    head = int(rpc(url, "eth_blockNumber", []), 16)
    tlds, start, step = [], DEPLOY_BLOCK, STEP
    while start <= head:
        query = {"address": SUFFIX_LIST, "topics": [topic], "fromBlock": hex(start), "toBlock": hex(min(start + step - 1, head))}
        try:
            logs = rpc(url, "eth_getLogs", [query])
        except RuntimeError as e:
            if "range" not in str(e).lower() or step == 1:
                raise
            step //= 2
            continue
        for log in logs:
            data = bytes.fromhex(log["data"][2:])
            parts = labels(data[64 : 64 + int.from_bytes(data[32:64], "big")])
            if len(parts) == 1 and parts[0] not in tlds:
                tlds.append(parts[0])
        start += step
    json.dump({"labels": tlds}, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
