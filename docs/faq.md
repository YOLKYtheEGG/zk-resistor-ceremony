# FAQ

## Why two phases?

Groth16 splits its trusted setup in two. Phase 1, the powers of tau, depends only on the elliptic curve, not the circuits. Phase 2 derives the per-circuit keys from it. Each is a separate contribution round. ZKResistor runs both itself because, unlike BN254, there is no public BLS12-381 powers of tau to reuse.

## How long does a contribution take?

Phase 1: a few minutes (`snarkjs powersoftau contribute`). Phase 2: about 30 minutes, mostly `snarkjs zkey contribute` running on your CPU, two circuits per slot.

## Do I need to be a cryptographer?

No. Run Docker, follow [CONTRIBUTING.md](../CONTRIBUTING.md).

## What if my contribution is wrong?

CI verifies your PR and fails with a clear error. Worst case, redo the contribution in a fresh container.

## Can I contribute anonymously?

Yes, with a pseudonym. The only requirement is that the same identity signs the attestation. GitHub-verified commits or GPG-signed attestation files both work.

## Can I contribute to both phases?

Yes. They are separate contribution windows; contribute to phase 1, phase 2, or both.

## Can I verify the ceremony without contributing?

Yes. Inside the Docker env, `./scripts/verify-previous.sh` checks the current head. To re-check every slot, run `snarkjs powersoftau verify` on each `phase1/*.ptau` and `snarkjs zkey verify` on each `phase2/*.zkey`. The transcript records every hash; re-derive each Drand round via https://api.drand.sh.

## What happens to my files after the ceremony?

They stay under `phase1/` and `phase2/` so anyone can re-verify the chain. They are public keys, meant to be widely distributed. The toxic waste is your random entropy, not the output; destroy the entropy and the output is safe to publish.

## My question is not here

Open an issue.
