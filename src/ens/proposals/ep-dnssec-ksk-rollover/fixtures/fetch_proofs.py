#!/usr/bin/env python3
"""Usage: python3 -I fixtures/fetch_proofs.py <RPC_URL> > fixtures/proofs.json"""

import json
import subprocess
import sys
import time
import urllib.request

GATEWAY = "https://dnssec-oracle.ens.domains/"
RESOLVER = "0xA4A2d86B30896fe5c4f2A7F2Ee0BDE3dbff26924"
TYPE_TXT = 16
NAMES = {
    "ensDomainsClaim": "_ens.ens.domains",
    "taytemsXyzGasless": "taytems.xyz",
}


def dns_encode(name):
    return b"".join(bytes([len(l)]) + l.encode() for l in name.strip(".").split(".")) + b"\x00"


def root_signature(proof):
    data = bytes.fromhex(proof[2:])
    u = lambda o: int.from_bytes(data[o : o + 32], "big")
    first = u(0) + 32 + u(u(0) + 32)
    rrset = data[first + u(first) + 32 :]
    return {
        "keyTag": int.from_bytes(rrset[16:18], "big"),
        "inception": int.from_bytes(rrset[12:16], "big"),
        "expiration": int.from_bytes(rrset[8:12], "big"),
    }


def gateway_proof(name):
    calldata = subprocess.check_output(
        ["cast", "calldata", "resolve(bytes,uint16)", "0x" + dns_encode(name).hex(), str(TYPE_TXT)], text=True
    ).strip()
    req = urllib.request.Request(
        GATEWAY,
        data=json.dumps({"data": calldata, "sender": RESOLVER}).encode(),
        headers={"content-type": "application/json", "user-agent": "dao-proposals/fetch_proofs"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)["data"]


def main():
    block = json.loads(subprocess.check_output(["cast", "block", "latest", "--json", "--rpc-url", sys.argv[1]], text=True))
    out = {"forkBlock": int(block["number"], 16), "forkTimestamp": int(block["timestamp"], 16), "proofs": {}}
    for key, name in NAMES.items():
        proof = gateway_proof(name)
        out["proofs"][key] = {"name": name, "rootSignature": root_signature(proof), "gateway": proof}
    json.dump(out, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
