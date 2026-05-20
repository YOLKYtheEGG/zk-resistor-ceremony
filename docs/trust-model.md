# Trust model

## What this ceremony protects

A Groth16 circuit has a structured reference string built in two phases.

**Phase 1** is the powers of tau: universal, circuit-independent, tied to the elliptic curve. ZKResistor's circuits are BLS12-381, because TON verifies BLS12-381 pairings on-chain. Unlike BN254, there is no large public BLS12-381 powers of tau to reuse, so this ceremony runs its own phase-1 chain.

**Phase 2** mixes each circuit's R1CS into the phase-1 output to produce its proving and verifying keys, for `insert.circom` and `withdraw.circom`.

If at least one contributor in a phase honestly destroys their entropy, that phase is sound. Otherwise the entropy holder can forge proofs for any statement under the resulting keys.

## What a malicious contributor can do alone

Nothing useful. Forging requires every other contributor in the same phase to also be malicious and aware of the prior entropy. One honest link in each phase breaks the attack. This is why diverse, independent contributors matter: collusion across people from different orgs and geographies is hard to credibly claim.

## What honest contributors do

Run the snarkjs contribution, discard the entropy, sign an attestation. The Docker workflow makes honesty the easy default: entropy lives in container memory and the container is discarded after the run.

## Drand beacon

Each phase closes with a [Drand](https://drand.love) round applied as a final mixing step. Drand is a distributed randomness service run by ~20 independent organizations; its output is publicly verifiable, unpredictable in advance, and not retroactively manipulable.

Two purposes: it defends against a fully-collusive contributor chain, since nobody could have known the Drand value before the round happened, and it is auditable, since anyone can re-derive it from the round number. The beacon does not replace human contributions; it adds an independent mixing step on top.

## Reproducibility

To verify the ceremony, an outside party needs:

1. The pinned R1CS files. `circom 2.2.3` produces bit-identical R1CS; see `circuits/README.md`.
2. To re-run `snarkjs powersoftau verify` on every `phase1/*.ptau` and `snarkjs zkey verify` on every `phase2/*.zkey`. The transcript records every hash.
3. To re-derive each Drand round to confirm the beacons.

The final `verifier-*-vk.tolk` constants in `TONresistor/zk-resistor-contracts` are fully determined by this chain.

## Out of scope

- Malicious frontend, wallet, or browser extension.
- Malicious RPC provider (TON liteservers sign responses; pick your endpoint).
- Bugs in the Tolk contracts (see the contracts repo).
- Bugs in `snarkjs 0.7.6` or `circom 2.2.3`.

## References

- snarkjs powers of tau and phase 2: https://github.com/iden3/snarkjs
- Drand: https://drand.love/docs/
