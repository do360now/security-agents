# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a defensive AI security system using the **advisor pattern** with the Claude model family: a faster executor (Sonnet 4.6 or Haiku 4.5) drives the loop, and a stronger advisor (Opus 4.7 / Opus 4.6 / Sonnet 4.6) is consulted at strategic decision points. The system helps defenders respond to AI-capable adversaries (e.g., Mythos-class autonomous exploit development).

## Architecture

**12 agents** in `.claude/agents/*.md`, each with:
- `executor` (fast tier) + `advisor` (stronger tier) — both Anthropic-served Claude models
- `integrity-hash-sha256` for agent integrity verification
- Frontmatter contract for model selection

Two 4-stage orchestrator panels share Stages 2, 3, and 4, plus a cross-panel reconciliation stage:

- **`security-panel`** (defensive) — `requirements-agent → risk-analysis-agent → solutions-agent → evaluator-agent`, writes to `/tmp/ai-security-panel/`
- **`red-team-panel`** (offensive) — `ares-agent → risk-analysis-agent → solutions-agent → evaluator-agent`, writes to `/tmp/ai-security-panel/red-team/`
- **`cross-panel`** — schema-validated reconciliation of both panels' SOLUTIONS.json into `both_panels`, `defensive_only`, `offensive_only`, `conflicts` buckets with an `agreement_ratio`. Run via `panel/run_stage.sh cross-panel`.

Run both panels for high-stakes systems; reconcile via the cross-panel stage. Stage 4 (`evaluator-agent`) runs in fresh context with no Write/Edit and returns PASS/NEEDS_WORK; max 2 evaluator iterations per panel run.

Stage 2 risk analysis fans out across REQ-*/ATK-* in parallel (3–5 sweet spot, batches above 10) when invoked as the main session — see `WORKFLOW.md`. Each panel-run writes a per-run `events.jsonl` so a dropped session can resume via `panel/wake.sh <output_dir>`.

**Recommended dispatch path (Round 4/5, smoke-tested end-to-end)**: panel stages are run through `panel/run_stage.sh`, which wraps `claude -p` with `--append-system-prompt-file panel/system-prompts/<stage>.md`, `--output-format json --json-schema panel/schemas/<stage>.schema.json`, and `--allowedTools <stage-specific list>`. This preserves Claude Code's default system prompt (so Sonnet retains real tool-use grounding) and validates each stage's output at the CLI boundary. Round 5 extended this to the offensive panel via the `attack-scenarios` stage. The legacy `subagent_type:` Agent-tool dispatch path is retained for one-off agent invocations but specialized subagent dispatch lost tool-use grounding in our smoke tests — prefer `panel/run_stage.sh` for multi-stage panels. See `WORKFLOW.md` for full runbooks.

**Dual runtime**: agents in `.claude/agents/` run on both Claude Code (canonical) and Copilot in VS Code (via the `@` mention picker / agents pane). Same frontmatter, same artifacts. The schema-validated `panel/run_stage.sh` pipeline runs through Claude Code only. See `README.md` § "Running agents: Claude Code vs Copilot in VS Code".

## Commands

```bash
# Red team test suite
make red-team-test          # Quick pass/fail summary
make red-team-full          # Detailed per-test output

# Show per-agent executor/advisor pairing and launch command
make start-security-agent     # Executor: claude-sonnet-4-6, Advisor: claude-opus-4-7
make start-requirements-agent
make start-solutions-agent
make start-risk-analysis-agent
make start-system-health-agent
make start-maintenance-agent
make start-security-panel

# Launch Claude Code on a specific model (interactive session)
make start-opus-4-7
make start-sonnet-4-6
make start-haiku-4-5

# Verify controls
./verify-all-agents.sh
./validate-makefile-models.sh
./validate-advisor-output.sh
./verify-skill-versions.sh
```

## Advisor invocation

Advisor calls are made via the Claude Code CLI in non-interactive print mode:

```bash
claude -p --model claude-opus-4-7 "$(cat <<'EOF'
You are a security advisor. Respond in under 100 words, enumerated steps only.

<stack>...</stack>
<findings>...</findings>
<question>...</question>
EOF
)"
```

This uses the caller's existing Anthropic authentication (OAuth or API key) — no separate credential store is needed.

## Critical Security Controls

See `WORKFLOW.md` for operator workflows (panel runs, scheduling, parallel fan-out).

- **Main session as orchestrator**: Panels (`security-panel`, `red-team-panel`) achieve full parallel fan-out only when invoked as the main session via `claude --agent <panel>`. Subagent invocation falls back to sequential execution. See `WORKFLOW.md`.
- **IDE diagnostic note**: Some IDE schemas flag full Claude model IDs (`claude-sonnet-4-6`, `claude-opus-4-7`) in `model:` frontmatter as "unknown" because they only know the aliases (`sonnet`, `opus`, `haiku`). This is a false positive — full IDs are documented as valid in the Claude Code sub-agents reference and are REQUIRED by `MODELS_ALLOWLIST.md` for exact-ID pinning. Do not switch to aliases.

1. **Advisor Output Validation** (MANDATORY before acting on advisor responses):
   - Run `validate-advisor-output.sh` — rejects raw bash, shell metacharacters, redirection
   - Advisor responses must be enumerated steps only, no compound commands
   - See `ADVISOR_OUTPUT_CONTRACT.md` for the full contract
   - **OWASP ASI01 (Prompt Injection)**: defended by this validation

2. **Model Allowlist**: Only Claude model IDs documented in `MODELS_ALLOWLIST.md` may be used. Because Claude models are Anthropic-served, integrity is via **exact-ID pinning + TLS** rather than a local weight digest.

3. **Kill Switch**: `SECURITY_INCIDENT_RUNBOOK.md` — full termination procedure if agents are compromised

4. **Output Durability**: Write findings to disk BEFORE calling the advisor — a dropped session mid-advice must not lose work

5. **Agent Integrity Verification**: Each agent has `integrity-hash-sha256` in frontmatter. Hashes are computed from the frontmatter block (excluding the hash line itself) with newlines preserved. Run `./verify-all-agents.sh` to verify.

6. **OWASP Agentic Top 10 Alignment (2026)**:
   - **ASI01 Prompt Injection**: Advisor output sandbox via `validate-advisor-output.sh`
   - **ASI02 Excessive Agency**: Agent tools explicitly declared in frontmatter; `system-health-agent` monitors for scope violations

7. **EU AI Act Compliance**: Full requirements take effect **August 2, 2026** — requires documented adversarial testing for high-risk AI systems

8. **JSON schema validation at stage boundaries (Round 4)**: every panel stage's output is validated against a schema in `panel/schemas/`. Schema-violating output causes the stage to fail and the orchestrator to halt — implementing the action-schema pattern from GitHub's multi-agent engineering guidance.

## Agent Invocation

For one-off audits, dispatch a single agent via the Agent tool (Claude Code) or `@<agent-name>` (Copilot in VS Code):

```bash
Agent(
  description: "Security audit of auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection, secret-leak, and authz bypass issues."
)
```

For full multi-stage panels, use the advisor-pattern dispatcher (Claude Code only):

```bash
panel/run_stage.sh requirements   /tmp/ai-security-panel/<TARGET>/ "<task>"
panel/run_stage.sh risk-analysis  /tmp/ai-security-panel/<TARGET>/ "<task>"
panel/run_stage.sh solutions      /tmp/ai-security-panel/<TARGET>/ "<task>"
```

For an offensive run, swap `requirements` for `attack-scenarios` and use `/tmp/ai-security-panel/red-team/<TARGET>/`.

## Adding New Agents

Frontmatter required fields:
```yaml
---
name: my-agent
description: One-line purpose
executor: claude-sonnet-4-6
advisor: claude-opus-4-7
model: claude-sonnet-4-6
integrity-hash-sha256: SHA256:<hash>
tools: Bash, Read, Write
disallowedTools: Edit
isolation: worktree
color: blue
maxTurns: 60
skills: []
---
```

- `model:` must match `executor:` — this is the field Claude Code actually uses
- `tools:` is a comma-separated string (not a YAML list)
- `disallowedTools:`, `isolation:`, `color:`, `maxTurns:` are optional
- Compute `integrity-hash-sha256:` with the canonical command in `verify-all-agents.sh`
