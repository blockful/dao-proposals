# Tornado Cash — Proposal 67 (malicious)

Proposal 67 is disguised as a relayer-fee change with a token-burn mechanism. In reality, its target contract is an
**unverified, counterfeit Relayer Registry** whose privileged roles (`governance()`, `staking()`) resolve to
attacker-controlled **vanity look-alike addresses**. If executed, it would let the attacker zero any relayer's stake via
`nullifyBalance`, disabling the operators that make private withdrawals possible.

This is an attack on the **protocol**, not the **treasury**: the DAO's ~7.32M TORN answers only to the real governance
proxy, which the spoofed addresses cannot impersonate.

Disclosure: [L2Beat (S. Shemyakov)](https://x.com/sergeyshemyakov/status/2070114103968887007),
[pcaversaccio](https://x.com/pcaversaccio/status/2070125180261896246). Decompilation:
[pcaversaccio gist via Dedaub](https://gist.github.com/pcaversaccio/958061a12d77dd0f5d03f145349f5f1b).

#### What's inside?

- [Governance proxy (real)](https://etherscan.io/address/0x5efda50f22d34F262c29268506C5Fa42cB56A1Ce#code) — treasury
  authority
- [TORN token](https://etherscan.io/address/0x77777FeDdddFfC19Ff86DB637967013e6C6A116C#code)
- [Governance Vault](https://etherscan.io/address/0x2F50508a8a3D323B91336FA3eA6ae50E55f32185#code) — treasury custody
- [Proposal 67 payload (unverified)](https://etherscan.io/address/0x0D0BE561052d4cf419575E35dE4e60163a55185B) —
  counterfeit registry
- Spoofed `governance()` -> `0x5EFDa50f22D34F272c7077689d6ABc42F15E285f`
- Spoofed `staking()` -> `0x2Fc93484614A34F7dBF98D7f7e997f6424e54a32`

#### Findings (verified on a mainnet fork)

| Check                                                    | Result    |
| -------------------------------------------------------- | --------- |
| `governance()` / `staking()` are vanity look-alikes      | confirmed |
| `nullifyBalance` gated to attacker only (DAO locked out) | confirmed |
| Treasury unreachable by the attacker (every vector)      | confirmed |
| Treasury fully drainable by the real proxy (contrast)    | confirmed |

A human-readable security report is in [`audit.html`](./audit.html).

### Tests

These tests fork mainnet and **require a non-censoring `MAINNET_RPC_URL`** — several public RPCs (llamarpc, cloudflare)
block Tornado Cash calls (OFAC). The pinned-block run also requires an **archive** endpoint.

```sh
$ MAINNET_RPC_URL=<non-censoring-archive-rpc> forge test --match-path "src/tornado/proposals/67/**" -vvv
```
