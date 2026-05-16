#!/usr/bin/env bash
set -euo pipefail

# Stop hook — commit-on-stop.sh
# Auto-commits tracked-file changes at session end.
# Default OFF: only fires when $CLAUDE_PROJECT_DIR/.claude/AUTO_COMMIT_ENABLED exists.
# Never blocks session end — always exits 0.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
MARKER="${PROJECT_DIR}/.claude/AUTO_COMMIT_ENABLED"

# Feature disabled by default — skip silently.
if [[ ! -f "${MARKER}" ]]; then
    exit 0
fi

# Must be inside a git repo.
if ! git -C "${PROJECT_DIR}" rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

GIT_DIR="$(git -C "${PROJECT_DIR}" rev-parse --git-dir)"

# Skip during rebase or merge — committing mid-rebase is dangerous.
for conflict_marker in MERGE_HEAD REBASE_HEAD rebase-merge rebase-apply; do
    if [[ -e "${GIT_DIR}/${conflict_marker}" ]]; then
        exit 0
    fi
done

# Commit only if tracked files have uncommitted changes.
if ! git -C "${PROJECT_DIR}" diff --quiet HEAD -- 2>/dev/null; then
    git -C "${PROJECT_DIR}" add -u
    git -C "${PROJECT_DIR}" commit -m "$(printf 'auto: session checkpoint at %s\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>\n' "$(date -Iseconds)")"
fi

exit 0