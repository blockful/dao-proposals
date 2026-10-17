#!/usr/bin/env bash
# Rebuilds the DNSSECImpl / OffchainDNSResolver / DNSRegistrar artifacts in ./artifacts from
# ensdomains/ens-contracts at the commit the proposal names (PR #572, merged to `staging`).
#
# The proposal's contracts are not deployed yet, so calldataCheck.t.sol deploys these
# artifacts on a fork in their place. Sources are compiled unmodified, with the compiler
# settings from upstream's hardhat.config.ts, so the runtime bytecode can later be diffed
# against what ENS Labs deploys (see `deployedBytecode` + `immutableReferences`).
#
# Usage: src/ens/proposals/ep-dnssec-ksk-rollover/upstream/build.sh
# Then:  git diff --exit-code src/ens/proposals/ep-dnssec-ksk-rollover/upstream/artifacts
set -euo pipefail

COMMIT=f0151aaf8a53b5b8f725a584fc194997c8226fbd
OUT="$(cd "$(dirname "$0")" && pwd)/artifacts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. Upstream source at the pinned commit
git -C "$WORK" init -q src
git -C "$WORK/src" fetch -q --depth 1 https://github.com/ensdomains/ens-contracts.git "$COMMIT"
git -C "$WORK/src" checkout -q FETCH_HEAD
test "$(git -C "$WORK/src" rev-parse HEAD)" = "$COMMIT"

# 2. Build directory: its own config, the upstream `contracts/` tree copied in (so source unit
#    names match hardhat's, `contracts/...`), and the three Solidity dependencies the contracts
#    import, at the versions in upstream's bun.lock. No install scripts run. Every path the
#    compiler sees is relative to this directory, so the metadata hash does not depend on where
#    it was built. The build never runs from inside the downloaded tree.
B="$WORK/build"
mkdir -p "$B"
cp -R "$WORK/src/contracts" "$B/contracts"
echo '{"private":true}' > "$B/package.json"
npm install --prefix "$B" --ignore-scripts --no-audit --no-fund --silent \
    @openzeppelin/contracts@4.9.3 \
    "@openzeppelin/contracts-v5@npm:@openzeppelin/contracts@5.1.0" \
    @ensdomains/buffer@0.1.3

# 3. Compile with upstream's settings (hardhat.config.ts: 0.8.26, optimizer 1_000_000 runs,
#    evmVersion paris, ipfs metadata hash, literal content). Only the three files passed to
#    `forge build` and their imports are compiled, not the whole tree.
cat > "$B/foundry.toml" <<'TOML'
[profile.default]
src = "contracts"
out = "out"
libs = []
solc = "0.8.26"
auto_detect_solc = false
optimizer = true
optimizer_runs = 1_000_000
evm_version = "paris"
bytecode_hash = "ipfs"
use_literal_content = true
remappings = [
  "@openzeppelin/contracts-v5/=node_modules/@openzeppelin/contracts-v5/",
  "@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/",
  "@ensdomains/buffer/=node_modules/@ensdomains/buffer/",
]
TOML
forge build --root "$B" \
    contracts/dnssec-oracle/DNSSECImpl.sol \
    contracts/dnsregistrar/OffchainDNSResolver.sol \
    contracts/dnsregistrar/DNSRegistrar.sol

# 4. Keep only what the test and a later bytecode diff need.
mkdir -p "$OUT"
for c in DNSSECImpl OffchainDNSResolver DNSRegistrar; do
    src="$(find "$B/out" -path "*/$c.sol/$c.json" | head -1)"
    jq --arg commit "$COMMIT" '{
        source: ("ensdomains/ens-contracts@" + $commit),
        compiler: .metadata.compiler.version,
        abi,
        bytecode: { object: .bytecode.object },
        deployedBytecode: {
            object: .deployedBytecode.object,
            immutableReferences: .deployedBytecode.immutableReferences
        }
    }' "$src" > "$OUT/$c.json"
done
echo "Wrote $(ls "$OUT" | wc -l | tr -d ' ') artifacts to $OUT"
