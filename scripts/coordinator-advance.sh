#!/usr/bin/env bash
# coordinator-advance.sh <DRAND_ROUND>
#
# Closes phase 1 and opens phase 2:
#   1. applies the Drand beacon as the final phase-1 contribution
#   2. prepares the phase-2 powers of tau
#   3. runs groth16 setup for both circuits (phase-2 slot 0)

set -euo pipefail
source "$(dirname "$0")/lib.sh"

if [ $# -ne 1 ]; then
    echo "usage: $0 <DRAND_ROUND>" >&2
    exit 2
fi
DRAND_ROUND=$1

if [ "$(ceremony_stage)" != "phase1" ]; then
    echo "Expected an open phase 1, found stage '$(ceremony_stage)'." >&2
    exit 1
fi

for f in circuits/insert.r1cs circuits/withdraw.r1cs; do
    if [ ! -f "$f" ]; then
        echo "Missing pinned R1CS: $f" >&2
        exit 1
    fi
done

LAST=$(ls phase1/pot_*.ptau 2>/dev/null | sort -V | tail -1 || true)
PREV=$(basename "$LAST" | sed -E 's/^pot_0*([0-9]+)_.*/\1/')
NEXT=$((PREV + 1))
SLOT=$(printf '%04d' "$NEXT")
BEACON_PTAU="phase1/pot_${SLOT}_drand-beacon.ptau"

DRAND_CHAIN="8990e7a9aaed2ffed73dbd7092123d6f289930540d7651336225dc172e51b2ce"
echo "Fetching Drand round $DRAND_ROUND ..."
DRAND_RANDOMNESS=$(curl -fsSL "https://api.drand.sh/${DRAND_CHAIN}/public/${DRAND_ROUND}" | jq -r .randomness)
if [ -z "$DRAND_RANDOMNESS" ] || [ "$DRAND_RANDOMNESS" = "null" ]; then
    echo "Could not fetch Drand round $DRAND_ROUND." >&2
    exit 1
fi
echo "Drand randomness: $DRAND_RANDOMNESS"

echo "Applying beacon to phase 1 ..."
snarkjs powersoftau beacon "$LAST" "$BEACON_PTAU" "$DRAND_RANDOMNESS" 10 -n="Drand round $DRAND_ROUND"
snarkjs powersoftau verify "$BEACON_PTAU"

echo "Preparing phase 2 ..."
mkdir -p build
snarkjs powersoftau prepare phase2 "$BEACON_PTAU" "$POT_FINAL" -v

echo "groth16 setup for both circuits ..."
mkdir -p phase2
INSERT0="phase2/insert_0000_initial.zkey"
WITHDRAW0="phase2/withdraw_0000_initial.zkey"
snarkjs groth16 setup circuits/insert.r1cs   "$POT_FINAL" "$INSERT0"
snarkjs groth16 setup circuits/withdraw.r1cs "$POT_FINAL" "$WITHDRAW0"

DATE_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BEACON_HASH=$(sha256_of "$BEACON_PTAU")
HI=$(sha256_of "$INSERT0")
HW=$(sha256_of "$WITHDRAW0")

node --input-type=module -e "
import { readFileSync, writeFileSync } from 'node:fs';
const t = JSON.parse(readFileSync('$TRANSCRIPT', 'utf8'));
t.contributions.push({stage:'phase1',slot:$NEXT,name:'drand-beacon',timestamp:'$DATE_ISO',ptau:'$BEACON_PTAU',ptau_hash:'$BEACON_HASH',attestation:null,drand_round:$DRAND_ROUND,drand_randomness:'$DRAND_RANDOMNESS'});
t.contributions.push({stage:'phase2',slot:0,name:'initial',timestamp:'$DATE_ISO',insert_zkey:'$INSERT0',withdraw_zkey:'$WITHDRAW0',insert_zkey_hash:'$HI',withdraw_zkey_hash:'$HW',attestation:null});
writeFileSync('$TRANSCRIPT', JSON.stringify(t, null, 2) + '\n');
"

echo
echo "Phase 1 closed, phase 2 open."
echo "  phase1 beacon          $BEACON_HASH"
echo "  phase2 slot 0 insert   $HI"
echo "  phase2 slot 0 withdraw $HW"
echo
echo "Commit and push:"
echo "  git add phase1/ phase2/ transcript/contributions.json"
echo "  git commit -S -m 'phase1 beacon + phase2 slot 0'"
echo "  git push"
