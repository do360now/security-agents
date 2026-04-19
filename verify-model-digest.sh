#!/usr/bin/env bash
# verify-model-digest.sh — Verify Ollama model digest against allowlist
# Usage: ./verify-model-digest.sh <model-name>:cloud
# Exit 0 = verified, Exit 1 = digest mismatch, Exit 2 = model not in allowlist

set -euo pipefail

MODEL="$1"
ALLOWLIST="/home/cmc/git/claude/MODELS_ALLOWLIST.md"

if [[ ! -f "$ALLOWLIST" ]]; then
    echo "ERROR: Allowlist not found: $ALLOWLIST" >&2
    exit 2
fi

# Get actual digest from Ollama
ACTUAL_DIGEST=$(ollama show "$MODEL" 2>/dev/null | grep "Digest:" | awk '{print $2}')
if [[ -z "$ACTUAL_DIGEST" ]]; then
    echo "ERROR: Could not retrieve digest for $MODEL" >&2
    exit 2
fi

# Extract expected digest from allowlist
EXPECTED_DIGEST=$(grep -A2 "^### $MODEL$" "$ALLOWLIST" 2>/dev/null | grep "Digest" | awk '{print $3}' || true)

if [[ -z "$EXPECTED_DIGEST" ]]; then
    echo "FAIL: Model $MODEL not found in allowlist" >&2
    echo "  Run 'ollama show $MODEL' and add to MODELS_ALLOWLIST.md" >&2
    exit 2
fi

if [[ "$ACTUAL_DIGEST" == "$EXPECTED_DIGEST" ]]; then
    echo "PASS: Digest verified for $MODEL"
    exit 0
else
    echo "FAIL: Digest mismatch for $MODEL" >&2
    echo "  Expected: $EXPECTED_DIGEST" >&2
    echo "  Actual:   $ACTUAL_DIGEST" >&2
    exit 1
fi
