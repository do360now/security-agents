#!/usr/bin/env bash
# verify-model-digest.sh — Verify a Claude model ID is in the allowlist
# Usage: ./verify-model-digest.sh <claude-model-id>
# Exit 0 = allowlisted, Exit 1 = not listed, Exit 2 = allowlist missing
#
# Note: Claude models are served by Anthropic's API — there is no local weight
# file to hash. Integrity is established by pinning exact model IDs in the
# allowlist and communicating over TLS. This script enforces the ID pin.

set -euo pipefail

MODEL="${1:-}"
ALLOWLIST="$(dirname "$0")/MODELS_ALLOWLIST.md"

if [[ -z "$MODEL" ]]; then
    echo "Usage: $0 <claude-model-id>" >&2
    echo "Example: $0 claude-opus-4-7" >&2
    exit 2
fi

if [[ ! -f "$ALLOWLIST" ]]; then
    echo "ERROR: Allowlist not found: $ALLOWLIST" >&2
    exit 2
fi

# Reject obvious floating aliases before checking the allowlist
case "$MODEL" in
    *-latest|latest|claude-latest)
        echo "FAIL: Floating alias '$MODEL' is not permitted — pin an exact dated ID" >&2
        exit 1
        ;;
esac

# The allowlist lists each model with a heading: `### claude-opus-4-7`
# followed by a `- **Model ID**: \`claude-opus-4-7\`` line.
if grep -qE "^### $MODEL$" "$ALLOWLIST" && \
   grep -qE "^\- \*\*Model ID\*\*: \`$MODEL\`$" "$ALLOWLIST"; then
    echo "PASS: $MODEL is allowlisted"
    exit 0
fi

echo "FAIL: $MODEL is NOT in allowlist" >&2
echo "  Review $ALLOWLIST and add the model with approval, or use an allowlisted ID." >&2
exit 1
