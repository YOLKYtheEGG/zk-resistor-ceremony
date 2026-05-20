# Transcript

`contributions.json` is the authoritative record of the contribution chain. The `.ptau` and `.zkey` files themselves live under `phase1/` and `phase2/`.

## Schema

```jsonc
{
  "ceremony": "ZKResistor trusted setup",
  "curve": "bls12-381",
  "power": 16,
  "circuits": ["insert", "withdraw"],
  "contributions": [
    {
      "stage": "phase1",          // phase1 | phase2
      "slot": 0,                  // contiguous from 0 within each stage
      "name": "initial",          // contributor handle, or "drand-beacon"
      "timestamp": "...",         // ISO 8601 UTC
      "ptau": "phase1/pot_0000_initial.ptau",
      "ptau_hash": "sha256:...",
      "attestation": null         // null for slot 0 and beacons
    }
    // phase2 entries carry insert_zkey / withdraw_zkey and their hashes
    // beacon entries carry drand_round and drand_randomness
  ]
}
```

## Invariants

- Slots are a contiguous run from 0 within each stage.
- Each file's recorded hash matches the `sha256` of the file it points to.
- Each stage ends with a `drand-beacon` entry.

`scripts/validate-contributions.js` enforces the schema; CI runs it plus the hash and cryptographic checks on every PR.
