#!/usr/bin/env bash
# Builds the deployed DNSSEC contracts from ens-contracts #585 into ./artifacts
set -euo pipefail

COMMIT=767cd3748e6f3d66a8280e44c1d31782705ceb62
OUT="$(cd "$(dirname "$0")" && pwd)/artifacts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git -C "$WORK" init -q src
git -C "$WORK/src" fetch -q --depth 1 https://github.com/ensdomains/ens-contracts.git "$COMMIT"
git -C "$WORK/src" checkout -q FETCH_HEAD
test "$(git -C "$WORK/src" rev-parse HEAD)" = "$COMMIT"

B="$WORK/build"
mkdir -p "$B"
cp -R "$WORK/src/contracts" "$B/contracts"
echo '{"private":true}' > "$B/package.json"
npm install --prefix "$B" --ignore-scripts --no-audit --no-fund --silent \
    @openzeppelin/contracts@4.9.3 \
    "@openzeppelin/contracts-v5@npm:@openzeppelin/contracts@5.1.0" \
    @ensdomains/buffer@0.1.3

# same settings as upstream hardhat.config.ts
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
