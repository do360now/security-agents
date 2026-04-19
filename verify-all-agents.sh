#!/usr/bin/env bash
# verify-all-agents.sh — Verify all agent frontmatter hashes before session start
# Called by system-health-agent at session initialization

set -euo pipefail
FAIL_COUNT=0

for agent in .claude/agents/*.md; do
    # Extract expected hash from frontmatter (the line after integrity-hash-sha256:)
    EXPECTED=$(sed -n '/^---$/,/^---$/p' "$agent" | sed '1d;$d' | grep 'integrity-hash-sha256:' | awk -F: '{print $NF}' | tr -d ' ' || true)
    if [[ -z "$EXPECTED" ]]; then
        echo "WARN: No hash found in $agent — skipping"
        continue
    fi
    # Verify: compute hash of frontmatter excluding the hash field itself, then compare
    FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$agent" | sed '1d;$d')
    COMPUTED=$(printf '%s' "$FRONTMATTER" | grep -v 'integrity-hash-sha256:' | sha256sum | awk '{print $1}')
    if [[ "$COMPUTED" != "$EXPECTED" ]]; then
        echo "FAIL: Hash mismatch for $agent" >&2
        echo "  Expected: $EXPECTED" >&2
        echo "  Computed: $COMPUTED" >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
    else
        echo "PASS: $agent"
    fi
done

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "ERROR: $FAIL_COUNT agent(s) failed hash verification" >&2
    exit 1
fi
echo "All agents verified."
