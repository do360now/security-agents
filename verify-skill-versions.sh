#!/usr/bin/env bash
# verify-skill-versions.sh — Verify all skills have pinned versions
# Exit 0 = all pinned, Exit 1 = floating version found

set -euo pipefail
FAIL_COUNT=0

for agent in .claude/agents/*.md; do
    # Check for skills field without version
    if grep -q 'skills:' "$agent"; then
        # Check if version is pinned
        if grep -A5 'skills:' "$agent" | grep -qE '^\s+- name:'; then
            if ! grep -A5 'skills:' "$agent" | grep -qE 'version:|commit:'; then
                echo "WARN: $agent has skills without version pinning" >&2
                FAIL_COUNT=$((FAIL_COUNT+1))
            fi
        fi
    fi
done

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "ERROR: $FAIL_COUNT agent(s) have unpinned skill versions" >&2
    exit 1
fi
echo "All skill versions are pinned."
exit 0
