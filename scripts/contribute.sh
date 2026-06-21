#!/usr/bin/env bash
# contribute.sh <YOUR_NAME>
#
# Detects the open stage and contributes to it:
#   phase 1 -> snarkjs powersoftau contribute
#   phase 2 -> snarkjs zkey contribute (insert and withdraw)
# Writes the new files, drafts an attestation, appends the transcript.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

if [ $# -ne 1 ]; then
    echo "usage: $0 <YOUR_NAME>" >&2
    exit 2
fi
NAME=$1
if ! [[ "$NAME" =~ ^[a-zA-Z0-9_-]{1,32}$ ]]; then
    echo "Name must be 1-32 alphanumerics, dashes, or underscores." >&2
    exit 2
fi

STAGE=$(ceremony_stage)

# Phase-2 contributions carry a -p2 tag so a handle is never confused with, or
# overwrites, its phase-1 attestation. alice -> alice-p2.
if [ "$STAGE" = "phase2" ]; then
    NAME="${NAME}-p2"
fi
if [ "${#NAME}" -gt 32 ]; then
    echo "Handle is too long once tagged: '$NAME'. Use a shorter handle." >&2
    exit 2
fi
if [ -e "contributors/${NAME}.attestation.md" ]; then
    echo "Handle '$NAME' already used; pick a different name." >&2
    exit 2
fi
DATE_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo uncommitted)
ATTEST="contributors/${NAME}.attestation.md"

append_transcript() {  # <js-object-literal>
    node --input-type=module -e "
import { readFileSync, writeFileSync } from 'node:fs';
const t = JSON.parse(readFileSync('$TRANSCRIPT', 'utf8'));
t.contributions.push($1);
writeFileSync('$TRANSCRIPT', JSON.stringify(t, null, 2) + '\n');
"
}

draft_attestation() {  # <stage> <slot>
    mkdir -p contributors
    sed -e "s|<YOUR_HANDLE>|${NAME}|g" \
        -e "s|<STAGE>|$1|g" \
        -e "s|<SLOT_NUMBER>|$2|g" \
        -e "s|<DATE_ISO8601>|${DATE_ISO}|g" \
        -e "s|<REPO_COMMIT_SHA>|${COMMIT_SHA}|g" \
        ATTESTATION.template.md > "$ATTEST"
}

if [ "$STAGE" = "phase1" ]; then
    LAST=$(ls phase1/pot_*.ptau 2>/dev/null | sort -V | tail -1 || true)
    if [ -z "$LAST" ]; then
        echo "No phase-1 ptau to build on." >&2
        exit 1
    fi
    PREV=$(basename "$LAST" | sed -E 's/^pot_0*([0-9]+)_.*/\1/')
    NEXT=$((PREV + 1))
    SLOT=$(printf '%04d' "$NEXT")
    OUT="phase1/pot_${SLOT}_${NAME}.ptau"
    if [ -e "$OUT" ]; then
        echo "$OUT already exists; pick another name." >&2
        exit 1
    fi

    echo "Phase 1: contributing slot $NEXT on top of $LAST"
    ./scripts/verify-previous.sh
    echo
    echo "Type random characters for ~30 seconds when prompted."
    echo "No patterns, no passwords. snarkjs mixes your input with /dev/urandom."
    echo
    snarkjs powersoftau contribute "$LAST" "$OUT" --name="$NAME phase1 slot $NEXT" -v

    HASH=$(sha256_of "$OUT")
    append_transcript "{stage:'phase1',slot:$NEXT,name:'$NAME',timestamp:'$DATE_ISO',ptau:'$OUT',ptau_hash:'$HASH',attestation:'$ATTEST',repo_commit:'$COMMIT_SHA'}"
    draft_attestation phase1 "$NEXT"

    echo
    echo "Done. phase1 slot $NEXT  $HASH"
    BRANCH="phase1-slot-${SLOT}-${NAME}"
    ADD="git add phase1/ contributors/ transcript/contributions.json"

elif [ "$STAGE" = "phase2" ]; then
    ensure_pot_final
    LAST_I=$(ls phase2/insert_*.zkey 2>/dev/null | sort -V | tail -1 || true)
    LAST_W=$(ls phase2/withdraw_*.zkey 2>/dev/null | sort -V | tail -1 || true)
    if [ -z "$LAST_I" ] || [ -z "$LAST_W" ]; then
        echo "No phase-2 zkey to build on." >&2
        exit 1
    fi
    PREV=$(basename "$LAST_I" | sed -E 's/^insert_0*([0-9]+)_.*/\1/')
    NEXT=$((PREV + 1))
    SLOT=$(printf '%04d' "$NEXT")
    OUT_I="phase2/insert_${SLOT}_${NAME}.zkey"
    OUT_W="phase2/withdraw_${SLOT}_${NAME}.zkey"
    if [ -e "$OUT_I" ] || [ -e "$OUT_W" ]; then
        echo "Slot $NEXT files already exist; pick another name." >&2
        exit 1
    fi

    echo "Phase 2: contributing slot $NEXT"
    ./scripts/verify-previous.sh
    echo
    echo "Type random characters for ~30 seconds when prompted (once per circuit)."
    echo
    snarkjs zkey contribute "$LAST_I" "$OUT_I" --name="$NAME phase2 slot $NEXT insert" -v
    snarkjs zkey contribute "$LAST_W" "$OUT_W" --name="$NAME phase2 slot $NEXT withdraw" -v

    HI=$(sha256_of "$OUT_I")
    HW=$(sha256_of "$OUT_W")
    append_transcript "{stage:'phase2',slot:$NEXT,name:'$NAME',timestamp:'$DATE_ISO',insert_zkey:'$OUT_I',withdraw_zkey:'$OUT_W',insert_zkey_hash:'$HI',withdraw_zkey_hash:'$HW',attestation:'$ATTEST',repo_commit:'$COMMIT_SHA'}"
    draft_attestation phase2 "$NEXT"

    echo
    echo "Done. phase2 slot $NEXT"
    echo "  insert   $HI"
    echo "  withdraw $HW"
    BRANCH="phase2-slot-${SLOT}-${NAME}"
    ADD="git add phase2/ contributors/ transcript/contributions.json"

else
    echo "Nothing to contribute: ceremony stage is '$STAGE'." >&2
    if [ "$STAGE" = "phase1-closed" ]; then
        echo "Phase 1 is finalized; wait for the coordinator to open phase 2." >&2
    fi
    exit 1
fi

echo
echo "Draft attestation written to $ATTEST."
echo "Sign it, then open the PR:"
echo "  gpg --clearsign $ATTEST && mv ${ATTEST}.asc $ATTEST   (optional)"
echo "  git checkout -b $BRANCH"
echo "  $ADD"
echo "  git commit -S -m '$BRANCH'"
echo "  git push origin HEAD"
echo "  gh pr create --title '$BRANCH'"
