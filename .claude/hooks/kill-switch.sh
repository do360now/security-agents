#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook — kill-switch.sh
# If $CLAUDE_PROJECT_DIR/AGENT_STOP exists, block all tool calls and print reason.
# Create the file to halt agents; remove it to resume.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STOP_FILE="${PROJECT_DIR}/AGENT_STOP"

if [[ -f "${STOP_FILE}" ]]; then
    reason="$(cat "${STOP_FILE}" 2>/dev/null)"
    if [[ -z "${reason}" ]]; then
        reason="AGENT_STOP file present — all tool calls blocked by operator kill-switch."
    fi
    echo "[kill-switch] BLOCKED: ${reason}" >&2
    exit 2
fi

exit 0