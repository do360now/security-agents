#!/usr/bin/env bash
# validate-advisor-output.sh — Validate advisor output against documented contract
# Usage: cat advisor-output.txt | ./validate-advisor-output.sh
# Exit 0 = valid, Exit 1 = contract violation

set -euo pipefail

OUTPUT=$(cat)

# Check 1: Non-empty
if [[ -z "$OUTPUT" ]]; then
    echo "FAIL: Empty output" >&2
    exit 1
fi

# Check 2: Contains enumerated steps (numbered list)
if ! echo "$OUTPUT" | grep -qE '^[0-9]+\.'; then
    echo "FAIL: No enumerated steps found" >&2
    exit 1
fi

# Check 3: No raw bash commands
if echo "$OUTPUT" | grep -qi 'Bash'; then
    echo "FAIL: Raw 'Bash' command in response — violates contract" >&2
    exit 1
fi

# Check 4: No shell metacharacters in any step
if echo "$OUTPUT" | grep -qE '&&|\|卧|\;|\$\(|`|\\'; then
    echo "FAIL: Shell metacharacters in response — violates contract" >&2
    exit 1
fi

# Check 5: No file redirection
if echo "$OUTPUT" | grep -qE '> /|>> /|2> /'; then
    echo "FAIL: File redirection in response — violates contract" >&2
    exit 1
fi

# Check 6: No external URLs
if echo "$OUTPUT" | grep -qE 'http://|https://'; then
    echo "FAIL: External URL in response — violates contract" >&2
    exit 1
fi

echo "PASS: Advisor output validated against contract"
exit 0
