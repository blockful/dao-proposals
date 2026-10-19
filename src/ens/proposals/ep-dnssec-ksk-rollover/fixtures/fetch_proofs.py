#!/usr/bin/env python3
"""Snapshot the DNSSEC proofs calldataCheck.t.sol replays on a fork.

For each name, two proofs of its TXT RRset are stored as ABI-encoded
DNSSEC.RRSetWithSignature[]:

  gateway  - exactly what https://dnssec-oracle.ens.domains/ returns (the gateway the
             current OffchainDNSResolver points at). Its first link is whatever root
             DNSKEY signature the gateway serves.
  ksk2024  - the same chain with link 0 replaced by the root DNSKEY RRset as served by
             a.root-servers.net, which since 2026-10-11 is signed only by KSK-2024
             (key tag 38696). Every other link is the gateway's.

RRSIGs expire, so the proofs only verify inside the window recorded in the output; the
test pins its fork to `forkBlock` and replays the proofs at `proofTime`.

Usage: python3 -I fixtures/fetch_proofs.py <RPC_URL> > fixtures/proofs.json
Needs `dig` and network access.
"""

import base64
import calendar
import json
import subprocess
import sys
import time
import urllib.request

GATEWAY = "https://dnssec-oracle.ens.domains/"
# Current OffchainDNSResolver, sent as the CCIP-Read `sender`.
CURRENT_RESOLVER = "0xF142B308cF687d4358410a4cB885513b30A42025"
ROOT_SERVER = "a.root-servers.net"
TYPE_TXT = 16
TYPE_DNSKEY = 48
# fixture key -> name whose TXT RRset is proven
NAMES = {
    "ensDomainsClaim": "_ens.ens.domains",  # imported name; TXT "a=0x..." for proveAndClaim
    "taytemsXyzGasless": "taytems.xyz",  # gasless name; TXT "ENS1 <resolver> <context>"
}


def dns_encode(name):
    out = b""
    for label in name.strip(".").split("."):
        if label:
            out += bytes([len(label)]) + label.encode()
    return out + b"\x00"


def word(n):
    return n.to_bytes(32, "big")


def enc_bytes(b):
    return word(len(b)) + b + b"\x00" * ((32 - len(b) % 32) % 32)


def abi_encode_rrsets(rrsets):
    """abi.encode(DNSSEC.RRSetWithSignature[]) for [(rrset, sig), ...]."""
    tuples = []
    for rrset, sig in rrsets:
        a, b = enc_bytes(rrset), enc_bytes(sig)
        tuples.append(word(64) + word(64 + len(a)) + a + b)
    head, body, off = b"", b"", 32 * len(tuples)
    for t in tuples:
        head += word(off)
        body += t
        off += len(t)
    return word(32) + word(len(tuples)) + head + body


def abi_decode_rrsets(data):
    u = lambda o: int.from_bytes(data[o : o + 32], "big")
    base = u(0) + 32
    out = []
    for i in range(u(base - 32)):
        t = base + u(base + 32 * i)

        def field(rel):
            p = t + u(t + rel)
            return data[p + 32 : p + 32 + u(p)]

        out.append((field(0), field(32)))
    return out


def gateway_proof(name):
    calldata = subprocess.check_output(
        ["cast", "calldata", "resolve(bytes,uint16)", "0x" + dns_encode(name).hex(), str(TYPE_TXT)],
        text=True,
    ).strip()
    req = urllib.request.Request(
        GATEWAY,
        data=json.dumps({"data": calldata, "sender": CURRENT_RESOLVER}).encode(),
        # The gateway rejects urllib's default User-Agent with a 403.
        headers={"content-type": "application/json", "user-agent": "dao-proposals/fetch_proofs"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return bytes.fromhex(json.load(r)["data"][2:])


def dns_time(s):
    return calendar.timegm(time.strptime(s, "%Y%m%d%H%M%S"))


def root_dnskey_link():
    """Root DNSKEY RRset + its RRSIG, in the oracle's (rrset, sig) wire format."""
    lines = subprocess.check_output(
        ["dig", "+dnssec", "+norecurse", "+nomultiline", "+noall", "+answer", ".", "DNSKEY", "@" + ROOT_SERVER],
        text=True,
    ).splitlines()
    keys, sigs = [], []
    for line in lines:
        f = line.split()
        if len(f) > 4 and f[3] == "DNSKEY":
            flags, proto, alg = int(f[4]), int(f[5]), int(f[6])
            keys.append(flags.to_bytes(2, "big") + bytes([proto, alg]) + base64.b64decode("".join(f[7:])))
        elif len(f) > 4 and f[3] == "RRSIG" and f[4] == "DNSKEY":
            sigs.append(f)
    if len(sigs) != 1:
        sys.exit(f"expected one root DNSKEY RRSIG, got {len(sigs)}")
    s = sigs[0]
    alg, labels, ttl = int(s[5]), int(s[6]), int(s[7])
    expiration, inception, key_tag = dns_time(s[8]), dns_time(s[9]), int(s[10])
    if s[11] != ".":
        sys.exit("root DNSKEY RRSIG signer is not the root")
    # RFC 4034 3.1.8.1: RRSIG RDATA without the signature, then the RRs in canonical
    # form (owner = root, TTL = original TTL), sorted by RDATA.
    rrset = (
        TYPE_DNSKEY.to_bytes(2, "big")
        + bytes([alg, labels])
        + ttl.to_bytes(4, "big")
        + expiration.to_bytes(4, "big")
        + inception.to_bytes(4, "big")
        + key_tag.to_bytes(2, "big")
        + b"\x00"
    )
    for rdata in sorted(keys):
        rrset += b"\x00" + TYPE_DNSKEY.to_bytes(2, "big") + (1).to_bytes(2, "big")
        rrset += ttl.to_bytes(4, "big") + len(rdata).to_bytes(2, "big") + rdata
    return (rrset, base64.b64decode("".join(s[12:]))), key_tag, inception, expiration


def window(links):
    """Latest inception and earliest expiry across a chain's RRSIGs."""
    return {
        "inception": max(int.from_bytes(r[12:16], "big") for r, _ in links),
        "expiration": min(int.from_bytes(r[8:12], "big") for r, _ in links),
    }


def main():
    rpc = sys.argv[1]
    block = json.loads(
        subprocess.check_output(["cast", "block", "latest", "--json", "--rpc-url", rpc], text=True)
    )
    root_link, root_tag, root_inc, root_exp = root_dnskey_link()
    out = {
        "fetchedAt": int(time.time()),
        "forkBlock": int(block["number"], 16),
        "forkTimestamp": int(block["timestamp"], 16),
        "gateway": GATEWAY,
        "rootDnskeyFrom": ROOT_SERVER,
        "rootDnskeyKeyTag": root_tag,
        "rootDnskeyInception": root_inc,
        "rootDnskeyExpiration": root_exp,
        "proofs": {},
    }
    for key, name in NAMES.items():
        gw = abi_decode_rrsets(gateway_proof(name))
        ksk = [root_link] + gw[1:]
        out["proofs"][key] = {
            "name": name,
            "dnsName": "0x" + dns_encode(name).hex(),
            "gatewayRootKeyTag": int.from_bytes(gw[0][0][16:18], "big"),
            "gatewayRootInception": int.from_bytes(gw[0][0][12:16], "big"),
            "gatewayRootExpiration": int.from_bytes(gw[0][0][8:12], "big"),
            "gatewayWindow": window(gw),
            "ksk2024Window": window(ksk),
            "gateway": "0x" + abi_encode_rrsets(gw).hex(),
            "ksk2024": "0x" + abi_encode_rrsets(ksk).hex(),
        }
    json.dump(out, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
