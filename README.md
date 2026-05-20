# ZKResistor trusted setup ceremony

Multi-party setup for the two BLS12-381 Groth16 circuits used by [ZKResistor](https://github.com/TONresistor/zk-resistor-contracts). Anyone is welcome to contribute.

## Why

A Groth16 circuit needs a trusted setup. Such a setup is sound as long as one contributor honestly destroys their entropy. A solo setup forces every user to trust that one person; a multi-party setup makes collusion the only attack, and collusion gets harder with every participant.

## Two phases

The setup runs in two parts, in order:

- **Phase 1**, the BLS12-381 powers of tau (power 16). Universal, circuit-independent. There is no public BLS12-381 powers of tau to reuse, so this ceremony generates its own.
- **Phase 2**, the per-circuit keys for `insert` and `withdraw`, derived from the phase-1 output.

Each phase is its own contribution chain, needs at least one honest contributor of its own, and closes with a [Drand](https://drand.love) beacon.

## Contributing

Fork, run one script in Docker, open a PR. `scripts/contribute.sh` contributes to whichever phase is open. Full steps in [CONTRIBUTING.md](./CONTRIBUTING.md).

## Final beacon

Each phase closes with a future Drand round applied as the final mixing step. The round is posted here before it happens, so its value is unpredictable to everyone, including the coordinator, at commit time.

Drand round: **TBD** (announced before each phase closes).

## License

MIT.
