#!/usr/bin/env bash
# verify-agent-hash.sh — Computes and verifies frontmatter SHA-256 hashes for agent YAML files
# Usage: ./verify-agent-hash.sh <agent-md-file> [expected-hash]
# Exit 0 = verified, Exit 1 = mismatch/missing hash, Exit 2 = file not found

set -euo pipefail

AGENT_FILE="$1"
EXPECTED_HASH="${2:-}"

if [[ ! -f "$AGENT_FILE" ]]; then
    echo "ERROR: File not found: $AGENT_FILE" >&2
    exit 2
fi

# Extract frontmatter block: lines between first --- and second --- markers
FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$AGENT_FILE" | sed '1d;$d')

if [[ -z "$FRONTMATTER" ]]; then
    echo "ERROR: No frontmatter found in $AGENT_FILE" >&2
    exit 2
fi

# Compute SHA-256 of the frontmatter block (raw bytes, no trailing newline)
ACTUAL_HASH=$(printf '%s' "$FRONTMATTER" | sha256sum | awk '{print $1}')

if [[ -z "$EXPECTED_HASH" ]]; then
    # No expected hash provided — output computed hash for initial registration
    echo "Hash for $AGENT_FILE: SHA256:$ACTUAL_HASH"
    exit 0
fi

# Compare
if [[ "$ACTUAL_HASH" == "$EXPECTED_HASH" ]]; then
    echo "PASS: Hash verified for $AGENT_FILE"
    exit 0
else
    echo "FAIL: Hash mismatch for $AGENT_FILE" >&2
    echo "  Expected: $EXPECTED_HASH" >&2
    echo "  Computed: $ACTUAL_HASH" >&2
    exit 1
fi
