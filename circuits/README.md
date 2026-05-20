# Pinned circuit artifacts

The R1CS files the phase-2 setup runs against. The coordinator commits them verbatim before phase 2 opens. Any drift between these and what a contributor would produce by recompiling the circuits invalidates phase 2.

| File | What |
|---|---|
| `insert.r1cs` | Compiled R1CS for `insert.circom` |
| `withdraw.r1cs` | Compiled R1CS for `withdraw.circom` |

The powers of tau is not here. Phase 1 generates it under `phase1/`, and the phase-2 prepared file is regenerated locally as `build/pot_final.ptau`.

## Reproducing the R1CS

```bash
git clone --branch <pinned-tag> https://github.com/TONresistor/zk-resistor-contracts.git /tmp/contracts
cd /tmp/contracts/circuits
npm ci
npm run compile

diff /tmp/contracts/circuits/build/insert.r1cs   <repo>/circuits/insert.r1cs
diff /tmp/contracts/circuits/build/withdraw.r1cs <repo>/circuits/withdraw.r1cs
```

Both diffs must be empty. If either differs, stop and open an issue.

Constraint counts (from the pinned source):

- `insert`   25,105
- `withdraw` 14,537
