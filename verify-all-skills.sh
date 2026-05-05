#!/usr/bin/env bash
# verify-all-skills.sh — Verify all skill frontmatter hashes
# Hashes the frontmatter EXCLUDING the integrity-hash-sha256 field itself
# (same pattern as verify-all-agents.sh)

set -euo pipefail
FAIL_COUNT=0
PASS_COUNT=0
SKIP_COUNT=0

for skill in .claude/skills/*/SKILL.md; do
    skill_name=$(basename $(dirname "$skill"))

    # Extract expected hash from frontmatter
    EXPECTED=$(sed -n '/^---$/,/^---$/p' "$skill" | sed '1d;$d' | grep 'integrity-hash-sha256:' | awk -F: '{print $NF}' | tr -d ' ' || true)
    if [[ -z "$EXPECTED" ]]; then
        echo "WARN: $skill_name — no integrity-hash-sha256 declared"
        SKIP_COUNT=$((SKIP_COUNT+1))
        continue
    fi

    # Compute hash of frontmatter EXCLUDING the hash field itself
    FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$skill" | sed '1d;$d')
    COMPUTED=$(printf '%s' "$FRONTMATTER" | grep -v 'integrity-hash-sha256:' | sha256sum | awk '{print $1}')

    if [[ "$COMPUTED" != "$EXPECTED" ]]; then
        echo "FAIL: $skill_name — hash mismatch" >&2
        echo "  Expected: $EXPECTED" >&2
        echo "  Computed: $COMPUTED" >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
    else
        echo "PASS: $skill_name"
        PASS_COUNT=$((PASS_COUNT+1))
    fi
done

echo ""
echo "Skill integrity: $PASS_COUNT PASS, $FAIL_COUNT FAIL, $SKIP_COUNT SKIP"

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
exit 0
