#!/usr/bin/env python3
"""Compare the mainnet runtime bytecode of the deployed contracts with upstream/artifacts.

Immutables (from each artifact's immutableReferences) and the CBOR metadata tail are masked
on both sides, so a match means the executable code is identical to the pinned build.

Usage: python3 -I upstream/verify-deployed.py <RPC_URL>
Needs `cast`.
"""

import json
import os
import subprocess
import sys

DEPLOYED = {
    "DNSSECImpl": "0x668ad4467129d49ecbe6274d95197797c0e262aa",
    "DNSRegistrar": "0x084462610a20efbdb686b30fe587eca0e234d2ef",
    "OffchainDNSResolver": "0xa4a2d86b30896fe5c4f2a7f2ee0bde3dbff26924",
}


def strip_metadata(code):
    return code[: len(code) - int.from_bytes(code[-2:], "big") - 2]


def mask(code, refs):
    code = bytearray(code)
    for ranges in refs.values():
        for r in ranges:
            code[r["start"] : r["start"] + r["length"]] = bytes(r["length"])
    return bytes(code)


def main():
    rpc = sys.argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    ok = True
    for name, address in DEPLOYED.items():
        art = json.load(open(os.path.join(here, "artifacts", name + ".json")))
        refs = art["deployedBytecode"].get("immutableReferences") or {}
        local = bytes.fromhex(art["deployedBytecode"]["object"][2:])
        onchain = bytes.fromhex(
            subprocess.check_output(["cast", "code", address, "--rpc-url", rpc], text=True).strip()[2:]
        )
        match = strip_metadata(mask(local, refs)) == strip_metadata(mask(onchain, refs))
        ok &= match
        print(f"{name} {address}: {'MATCH' if match else 'DIFFERS'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
