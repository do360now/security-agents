# Claude Code Agents — Anthropic Orchestrator-Worker Pattern

Custom agents that pair a **planning-class model (Opus 4.7)** with **implementation-class workers (Sonnet 4.6, Haiku 4.5)**, following the orchestrator-worker pattern from Anthropic's [multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) and the evaluator-optimizer pattern from [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents).

All inference is Anthropic-only — `claude-opus-4-7`, `claude-sonnet-4-6`, and `claude-haiku-4-5`. No third-party providers, no local GPU.

## Why this split

Most work on agentic tasks is mechanical (listing files, running commands, reading output). The hard part is picking the *right plan*. Anthropic's evals show Opus-as-lead + Sonnet-as-workers beats single-agent Opus by ~90% on research tasks because token usage dominates the cost equation — and Sonnet calls are 5× cheaper than Opus per token. The pattern keeps token-heavy execution on Sonnet (or Haiku) and reserves Opus for the handful of decision points that matter.

Inspired by Ousterhout's "design is decomposition" and his [April 2025 commentary](https://newsletter.pragmaticengineer.com/p/the-philosophy-of-software-design) that AI tools make *more* design thinking necessary, not less — Opus carries the design load.

## Agents

| Agent | Executor | Advisor | Description |
|-------|----------|---------|-------------|
| `security-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Vulnerability scan, code review |
| `system-health-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | Process/resource diagnostics |
| `maintenance-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Updates, cleanup, optimization |
| `requirements-agent` | `claude-opus-4-7` | `claude-opus-4-7` | Threat-intel → testable requirements |
| `risk-analysis-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Red-team test generation |
| `solutions-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Defensive solution design |
| `security-panel` | `claude-opus-4-7` | `claude-opus-4-7` | Lead orchestrator for full 3-stage panel |

Model IDs map to the current generation per <https://platform.claude.com/docs/en/about-claude/models/overview>:

| Model | API ID | Role |
|-------|--------|------|
| Claude Opus 4.7 | `claude-opus-4-7` | Lead / advisor / planner |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | Worker / implementer |
| Claude Haiku 4.5 | `claude-haiku-4-5` | Lightweight diagnostics |

## Usage

```
Agent(
  description: "Audit auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection and authz issues."
)
```

## Advisor invocation

The executor shells out to the headless `claude` CLI at three moments: early (after orientation), when stuck, and before declaring done.

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

The single-quoted heredoc (`'EOF'`) is intentional — it disables shell expansion so any `$VAR` in advisor input stays literal.

## Adding agents

See `CLAUDE.md` in this directory for the frontmatter contract and body guidelines. After editing any agent file, run `./verify-all-agents.sh` and update `integrity-hash-sha256` with the computed hash.
