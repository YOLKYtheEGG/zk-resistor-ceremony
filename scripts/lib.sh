# lib.sh - shared helpers, sourced by the other scripts.
# Sourcing this file changes the working directory to the repo root.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_ROOT"

TRANSCRIPT="transcript/contributions.json"
POT_FINAL="build/pot_final.ptau"

# Echoes the current stage:
#   uninitialized | phase1 | phase1-closed | phase2 | done
ceremony_stage() {
    local p1 p2 p1b p2b
    p1=$(jq '[.contributions[]|select(.stage=="phase1")]|length' "$TRANSCRIPT")
    p2=$(jq '[.contributions[]|select(.stage=="phase2")]|length' "$TRANSCRIPT")
    p1b=$(jq '[.contributions[]|select(.stage=="phase1" and .name=="drand-beacon")]|length' "$TRANSCRIPT")
    p2b=$(jq '[.contributions[]|select(.stage=="phase2" and .name=="drand-beacon")]|length' "$TRANSCRIPT")
    if [ "$p2" -gt 0 ]; then
        if [ "$p2b" -gt 0 ]; then echo done; else echo phase2; fi
    elif [ "$p1" -gt 0 ]; then
        if [ "$p1b" -gt 0 ]; then echo phase1-closed; else echo phase1; fi
    else
        echo uninitialized
    fi
}

# Regenerates build/pot_final.ptau from the committed phase-1 beacon if absent.
# prepare phase2 is deterministic, so the ~108 MB final ptau is never committed.
ensure_pot_final() {
    if [ -f "$POT_FINAL" ]; then return 0; fi
    local beacon
    beacon=$(ls phase1/pot_*_drand-beacon.ptau 2>/dev/null | sort -V | tail -1 || true)
    if [ -z "$beacon" ]; then
        echo "Phase 1 has no beacon yet; cannot prepare phase 2." >&2
        return 1
    fi
    mkdir -p build
    echo "Regenerating $POT_FINAL from $beacon ..."
    snarkjs powersoftau prepare phase2 "$beacon" "$POT_FINAL" -v
}

sha256_of() { echo "sha256:$(sha256sum "$1" | cut -d' ' -f1)"; }
