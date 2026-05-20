#!/usr/bin/env bash
# coordinator-init.sh
#
# Run ONCE to open the ceremony. Starts phase 1: a fresh BLS12-381 powers of
# tau at power 16, and records phase-1 slot 0 in the transcript.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

POWER=16
SLOT0="phase1/pot_0000_initial.ptau"

if [ "$(ceremony_stage)" != "uninitialized" ]; then
    echo "Ceremony already initialized." >&2
    exit 1
fi

mkdir -p phase1
echo "Starting BLS12-381 powers of tau, power $POWER ..."
snarkjs powersoftau new bls12-381 "$POWER" "$SLOT0" -v

HASH=$(sha256_of "$SLOT0")
DATE_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$TRANSCRIPT" <<EOF
{
  "ceremony": "ZKResistor trusted setup",
  "curve": "bls12-381",
  "power": $POWER,
  "circuits": ["insert", "withdraw"],
  "contributions": [
    {
      "stage": "phase1",
      "slot": 0,
      "name": "initial",
      "timestamp": "${DATE_ISO}",
      "ptau": "${SLOT0}",
      "ptau_hash": "${HASH}",
      "attestation": null
    }
  ]
}
EOF

echo
echo "Phase 1 open. Slot 0 ${HASH}"
echo "Commit and push to invite contributors:"
echo "  git add phase1/ transcript/contributions.json"
echo "  git commit -S -m 'phase1 slot 0: initial'"
echo "  git push"
