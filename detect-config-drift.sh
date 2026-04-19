#!/usr/bin/env bash
# detect-config-drift.sh — Detect unauthorized configuration changes
# Run at session start by system-health-agent
# Exit 0 = no drift, Exit 1 = drift detected

set -euo pipefail

cd /home/cmc/git/claude

# Check 1: settings.local.json drift
if git diff --exit-code HEAD -- .claude/settings.local.json > /dev/null 2>&1; then
    echo "PASS: settings.local.json matches git HEAD"
else
    echo "ALERT: settings.local.json has been modified!" >&2
    git diff --color=never HEAD -- .claude/settings.local.json >&2
    echo "Run 'git checkout -- .claude/settings.local.json' to restore baseline" >&2
    exit 1
fi

# Check 2: Agent YAML drift (any .md file in agents/)
for agent in .claude/agents/*.md; do
    if git diff --exit-code HEAD -- "$agent" > /dev/null 2>&1; then
        echo "PASS: $agent matches git HEAD"
    else
        echo "ALERT: $agent has been modified!" >&2
        git diff --color=never HEAD -- "$agent" >&2
        exit 1
    fi
done

# Check 3: Verify frontmatter hash integrity (additional check)
./verify-all-agents.sh || {
    echo "ALERT: Agent frontmatter hash verification failed!" >&2
    exit 1
}

echo "All config drift checks passed."
exit 0
