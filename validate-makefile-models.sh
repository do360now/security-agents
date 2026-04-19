#!/usr/bin/env bash
# validate-makefile-models.sh — Verify all Ollama model references in Makefile are in allowlist
# Exit 0 = all models allowed, Exit 1 = unlisted model found

set -euo pipefail

ALLOWLIST="/home/cmc/git/claude/MODELS_ALLOWLIST.md"
MAKEFILE="/home/cmc/git/claude/Makefile"
FAIL_COUNT=0

if [[ ! -f "$ALLOWLIST" ]]; then
    echo "ERROR: Allowlist not found" >&2
    exit 2
fi

# Extract all model names from Makefile (from ollama run/launch commands)
MODELS=$(grep -E "ollama (run|launch)" "$MAKEFILE" 2>/dev/null | grep -oE '[a-zA-Z0-9._-]+:[a-zA-Z0-9_-]+' | sort -u)

for MODEL in $MODELS; do
    if grep -q "^### $MODEL$" "$ALLOWLIST"; then
        echo "PASS: $MODEL is in allowlist"
    else
        echo "FAIL: $MODEL is NOT in allowlist (Makefile line: $(grep -n "ollama.*$MODEL" "$MAKEFILE"))" >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
done

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "ERROR: $FAIL_COUNT unlisted model(s) in Makefile" >&2
    exit 1
fi
echo "All Makefile models verified."
