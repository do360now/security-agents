#!/usr/bin/env bash
set -euo pipefail

# UserPromptSubmit hook — steer.sh
# If STEER.md exists and is non-empty, injects its contents as additionalContext
# so the operator can steer ongoing agent behavior without editing prompts directly.
# STEER.md is left in place so steering persists across prompts.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STEER_PATH="${PROJECT_DIR}/STEER.md"

# No steering file or empty file — pass through silently.
if [[ ! -f "${STEER_PATH}" ]] || [[ ! -s "${STEER_PATH}" ]]; then
    exit 0
fi

# Emit JSON with steering content injected as additionalContext.
jq -n --rawfile ctx "${STEER_PATH}" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

exit 0