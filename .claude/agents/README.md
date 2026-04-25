# Claude Code Agents — Claude-family Advisor Pattern

Custom agents that pair a **fast executor** with a **stronger advisor** — both running on Anthropic's Claude model family. Loosely modelled on Anthropic's [advisor tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool).

## Why the advisor pattern

Most work on agentic tasks is mechanical (listing files, running commands, reading output). The hard part is picking the *right plan*. The advisor pattern keeps token-heavy execution on a cheaper model (Haiku / Sonnet) and reserves the expensive model (Opus) for the handful of decision points that matter.

## Agents

| Agent | Executor | Advisor | Description |
|-------|----------|---------|-------------|
| `security-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Static vulnerability scan, code review |
| `tron-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Live intrusion detection (runtime defender) |
| `ares-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Outside-in adversary emulation (attack scenarios) |
| `clu-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Alignment & scope watchdog (intent-level ASI02 monitoring) |
| `system-health-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | Process/resource diagnostics |
| `maintenance-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | Updates, cleanup, optimization |
| `requirements-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Requirements from threat intel |
| `risk-analysis-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Risk scoring, red-team tests |
| `solutions-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Defensive solution design |
| `security-panel` | `claude-opus-4-7` | `claude-opus-4-6` | Defensive 3-stage pipeline (requirements → risk → solutions) |
| `red-team-panel` | `claude-opus-4-7` | `claude-opus-4-6` | Offensive 3-stage pipeline (ares → risk → solutions) |

Claude Code itself can be launched with any of these models (`claude --model claude-sonnet-4-6`). The agent shells out to other Claude models for advisor consultations via `claude -p --model ...` or via the Anthropic SDK. Pairing (fast ↔ strong) matters more than exact names — swap tiers based on cost/latency needs.

## Usage

```
Agent(
  description: "Audit auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection and authz issues."
)
```

## Advisor invocation

The executor shells out to Claude at three moments: early (after orientation), when stuck, and before declaring done.

```bash
claude -p --model claude-opus-4-7 "$(cat <<'EOF'
You are a security advisor. Respond in under 100 words, enumerated steps only.

<task>Audit src/auth/ for injection/authz issues</task>
<findings>
- login.py uses raw string concat in 3 queries
- session token stored in localStorage
- /admin/* routes check cookie presence, not signature
</findings>

Where should the executor look next, and what should it prioritize?
EOF
)"
```

## Adding agents

See `CLAUDE.md` in this directory for the frontmatter contract and body guidelines.
