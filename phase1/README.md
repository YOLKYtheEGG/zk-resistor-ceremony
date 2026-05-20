# Phase 1 - Powers of Tau

The universal BLS12-381 powers of tau, power 16. One `.ptau` file per slot:

```
pot_0000_initial.ptau          coordinator, snarkjs powersoftau new
pot_0001_<name>.ptau           contributor
pot_0002_<name>.ptau           contributor
...
pot_<NNNN>_drand-beacon.ptau   coordinator, final mixing step
```

The highest-numbered file is the current head; `scripts/contribute.sh` finds it automatically. Each file is around 36 MB.

Phase 1 does not depend on the circuits. Once it closes, the coordinator runs `prepare phase2` on the beacon file to produce the phase-2 powers of tau (`build/pot_final.ptau`, ~108 MB, deterministic so regenerated rather than committed).
