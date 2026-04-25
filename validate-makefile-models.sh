#!/usr/bin/env bash
# validate-makefile-models.sh — Verify all Claude model references in the
# Makefile are in the MODELS_ALLOWLIST.
# Exit 0 = all models allowed, Exit 1 = unlisted model found.

set -euo pipefail

ALLOWLIST="$(dirname "$0")/MODELS_ALLOWLIST.md"
MAKEFILE="$(dirname "$0")/Makefile"
FAIL_COUNT=0

if [[ ! -f "$ALLOWLIST" ]]; then
    echo "ERROR: Allowlist not found: $ALLOWLIST" >&2
    exit 2
fi

if [[ ! -f "$MAKEFILE" ]]; then
    echo "ERROR: Makefile not found: $MAKEFILE" >&2
    exit 2
fi

# Extract every `--model <id>` reference from the Makefile as well as every
# bare `claude-*` mention that looks like a model id in echoed help text.
MODELS=$(grep -oE -- '--model[[:space:]]+claude-[a-z0-9._-]+' "$MAKEFILE" \
    | awk '{print $2}' | sort -u)

# Also pick up bare `claude-<tier>-<version>` tokens that appear in echoed
# messages (surfacing any model referenced in docs that isn't allowlisted).
BARE=$(grep -oE 'claude-(opus|sonnet|haiku)-[0-9]+(-[0-9]+)?' "$MAKEFILE" \
    | sort -u)

ALL=$(printf '%s\n%s\n' "$MODELS" "$BARE" | sort -u | sed '/^$/d')

if [[ -z "$ALL" ]]; then
    echo "INFO: No Claude model references found in Makefile."
    exit 0
fi

for MODEL in $ALL; do
    # Reject obvious floating aliases
    case "$MODEL" in
        *-latest|latest)
            echo "FAIL: Floating alias '$MODEL' is not permitted" >&2
            FAIL_COUNT=$((FAIL_COUNT+1))
            continue
            ;;
    esac
    if grep -qE "^### $MODEL$" "$ALLOWLIST"; then
        echo "PASS: $MODEL is in allowlist"
    else
        LINE=$(grep -nE "$MODEL" "$MAKEFILE" | head -1)
        echo "FAIL: $MODEL is NOT in allowlist (Makefile line: $LINE)" >&2
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
done

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "ERROR: $FAIL_COUNT unlisted model(s) in Makefile" >&2
    exit 1
fi
echo "All Makefile models verified."
