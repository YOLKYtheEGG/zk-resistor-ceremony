#!/usr/bin/env bash
# verify-previous.sh
#
# Verifies the head of the current stage: the head file hashes match the
# transcript, the snarkjs cryptographic check passes, and the chain embeds
# one contribution per slot (guards against a contributor truncating the
# chain to drop earlier honest contributions).

set -euo pipefail
source "$(dirname "$0")/lib.sh"

STAGE=$(ceremony_stage)
VLOG=$(mktemp)
trap 'rm -f "$VLOG"' EXIT

check_chain_length() {  # <logfile> <expected_slot>
    local n
    n=$(grep -ciE 'contribution #[0-9]+' "$1" || true)
    if [ "$2" -gt 0 ] && [ "$n" -ne "$2" ]; then
        echo "Chain-length mismatch: head is slot $2 but embeds $n contributions." >&2
        echo "The head dropped earlier contributions. Do not build on it." >&2
        exit 1
    fi
    if [ "$2" -gt 0 ]; then
        echo "Chain length OK: $n contributions embedded."
    fi
}

if [ "$STAGE" = "phase1" ] || [ "$STAGE" = "phase1-closed" ]; then
    LAST=$(ls phase1/pot_*.ptau 2>/dev/null | sort -V | tail -1 || true)
    if [ -z "$LAST" ]; then
        echo "No phase-1 ptau found." >&2
        exit 1
    fi
    SLOT=$(jq -r '[.contributions[]|select(.stage=="phase1")]|last|.slot' "$TRANSCRIPT")
    EXPECT=$(jq -r --argjson s "$SLOT" '.contributions[]|select(.stage=="phase1" and .slot==$s)|.ptau_hash' "$TRANSCRIPT")
    if [ "$(sha256_of "$LAST")" != "$EXPECT" ]; then
        echo "Hash mismatch on $LAST (file vs transcript)." >&2
        exit 1
    fi
    if [ "$SLOT" -eq 0 ]; then
        echo "Hash matches transcript. Slot 0 is the initial powers of tau"
        echo "(deterministic, no contribution yet); the hash check is sufficient."
    else
        echo "Hash matches transcript. Verifying $LAST ..."
        snarkjs powersoftau verify "$LAST" | tee "$VLOG"
        check_chain_length "$VLOG" "$SLOT"
    fi

elif [ "$STAGE" = "phase2" ] || [ "$STAGE" = "done" ]; then
    ensure_pot_final
    LAST_I=$(ls phase2/insert_*.zkey 2>/dev/null | sort -V | tail -1 || true)
    LAST_W=$(ls phase2/withdraw_*.zkey 2>/dev/null | sort -V | tail -1 || true)
    if [ -z "$LAST_I" ] || [ -z "$LAST_W" ]; then
        echo "No phase-2 zkey found." >&2
        exit 1
    fi
    SLOT=$(jq -r '[.contributions[]|select(.stage=="phase2")]|last|.slot' "$TRANSCRIPT")
    EXP_I=$(jq -r --argjson s "$SLOT" '.contributions[]|select(.stage=="phase2" and .slot==$s)|.insert_zkey_hash' "$TRANSCRIPT")
    EXP_W=$(jq -r --argjson s "$SLOT" '.contributions[]|select(.stage=="phase2" and .slot==$s)|.withdraw_zkey_hash' "$TRANSCRIPT")
    if [ "$(sha256_of "$LAST_I")" != "$EXP_I" ]; then
        echo "Hash mismatch on $LAST_I." >&2
        exit 1
    fi
    if [ "$(sha256_of "$LAST_W")" != "$EXP_W" ]; then
        echo "Hash mismatch on $LAST_W." >&2
        exit 1
    fi
    echo "Hashes match transcript. Verifying insert ..."
    snarkjs zkey verify circuits/insert.r1cs "$POT_FINAL" "$LAST_I" | tee "$VLOG"
    check_chain_length "$VLOG" "$SLOT"
    echo "Verifying withdraw ..."
    snarkjs zkey verify circuits/withdraw.r1cs "$POT_FINAL" "$LAST_W" | tee "$VLOG"
    check_chain_length "$VLOG" "$SLOT"

else
    echo "Ceremony not initialized; nothing to verify." >&2
    exit 1
fi

echo
echo "Head verified."
