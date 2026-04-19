#!/usr/bin/env bash
# pre-commit-inline-script-check.sh — Detect inline scripts in agent configs
# Exit 0 = clean, Exit 1 = malicious pattern found

set -euo pipefail

FAIL_COUNT=0

for file in .claude/agents/*.md .claude/agents/*.yaml Makefile CLAUDE.md; do
    [[ -f "$file" ]] || continue

    # Only flag actual command substitutions with dangerous commands
    # This catches $(curl ...), $(wget ...), $(python -c ...) etc embedded in config files
    if grep -qE '\$\(curl\s|\$\(wget\s|\$\(python\s|\$\(ruby\s|\$\(perl\s|base64\s+-d' "$file" 2>/dev/null; then
        echo "FAIL: Dangerous command substitution in $file" >&2
        grep -nE '\$\(curl\s|\$\(wget\s|\$\(python\s|\$\(ruby\s|\$\(perl\s|base64\s+-d' "$file" >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
done

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "ERROR: $FAIL_COUNT file(s) with dangerous command substitutions" >&2
    exit 1
fi
echo "PASS: No dangerous command substitutions detected."
exit 0
