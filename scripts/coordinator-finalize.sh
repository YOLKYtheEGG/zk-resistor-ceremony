#!/usr/bin/env bash
# coordinator-finalize.sh <DRAND_ROUND>
#
# Closes phase 2: applies the Drand beacon as the final contribution to both
# circuits, verifies the result, and exports the verification keys.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

if [ $# -ne 1 ]; then
    echo "usage: $0 <DRAND_ROUND>" >&2
    exit 2
fi
DRAND_ROUND=$1

if [ "$(ceremony_stage)" != "phase2" ]; then
    echo "Expected an open phase 2, found stage '$(ceremony_stage)'." >&2
    exit 1
fi

ensure_pot_final

LAST_I=$(ls phase2/insert_*.zkey 2>/dev/null | sort -V | tail -1 || true)
LAST_W=$(ls phase2/withdraw_*.zkey 2>/dev/null | sort -V | tail -1 || true)
PREV=$(basename "$LAST_I" | sed -E 's/^insert_0*([0-9]+)_.*/\1/')
NEXT=$((PREV + 1))
SLOT=$(printf '%04d' "$NEXT")
BEACON_I="phase2/insert_${SLOT}_drand-beacon.zkey"
BEACON_W="phase2/withdraw_${SLOT}_drand-beacon.zkey"

DRAND_CHAIN="8990e7a9aaed2ffed73dbd7092123d6f289930540d7651336225dc172e51b2ce"
echo "Fetching Drand round $DRAND_ROUND ..."
DRAND_RANDOMNESS=$(curl -fsSL "https://api.drand.sh/${DRAND_CHAIN}/public/${DRAND_ROUND}" | jq -r .randomness)
if [ -z "$DRAND_RANDOMNESS" ] || [ "$DRAND_RANDOMNESS" = "null" ]; then
    echo "Could not fetch Drand round $DRAND_ROUND." >&2
    exit 1
fi

echo "Applying beacon to both circuits ..."
snarkjs zkey beacon "$LAST_I" "$BEACON_I" "$DRAND_RANDOMNESS" 10 -n="Drand round $DRAND_ROUND"
snarkjs zkey beacon "$LAST_W" "$BEACON_W" "$DRAND_RANDOMNESS" 10 -n="Drand round $DRAND_ROUND"

echo "Verifying final zkeys ..."
snarkjs zkey verify circuits/insert.r1cs   "$POT_FINAL" "$BEACON_I"
snarkjs zkey verify circuits/withdraw.r1cs "$POT_FINAL" "$BEACON_W"

echo "Exporting verification keys ..."
mkdir -p build
snarkjs zkey export verificationkey "$BEACON_I" build/insert_vk.json
snarkjs zkey export verificationkey "$BEACON_W" build/withdraw_vk.json

DATE_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HI=$(sha256_of "$BEACON_I")
HW=$(sha256_of "$BEACON_W")

node --input-type=module -e "
import { readFileSync, writeFileSync } from 'node:fs';
const t = JSON.parse(readFileSync('$TRANSCRIPT', 'utf8'));
t.contributions.push({stage:'phase2',slot:$NEXT,name:'drand-beacon',timestamp:'$DATE_ISO',insert_zkey:'$BEACON_I',withdraw_zkey:'$BEACON_W',insert_zkey_hash:'$HI',withdraw_zkey_hash:'$HW',attestation:null,drand_round:$DRAND_ROUND,drand_randomness:'$DRAND_RANDOMNESS'});
writeFileSync('$TRANSCRIPT', JSON.stringify(t, null, 2) + '\n');
"

echo
echo "Ceremony complete. VK JSON written to build/."
echo "Regenerate the Tolk constants in the contracts repo:"
echo "  cp build/insert_vk.json build/withdraw_vk.json ../zkresistor-contracts/circuits/build/"
echo "  cd ../zkresistor-contracts/circuits && npm run vk-to-tolk:insert && npm run vk-to-tolk:withdraw"
echo
echo "Commit and push the final slot:"
echo "  git add phase2/ transcript/contributions.json"
echo "  git commit -S -m 'phase2 beacon (round $DRAND_ROUND)'"
echo "  git push"
