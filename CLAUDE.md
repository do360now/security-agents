# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a defensive AI security system using the **advisor pattern** with the Claude model family: a faster executor (Sonnet 4.6 or Haiku 4.5) drives the loop, and a stronger advisor (Opus 4.7 / Opus 4.6 / Sonnet 4.6) is consulted at strategic decision points. The system helps defenders respond to AI-capable adversaries (e.g., Mythos-class autonomous exploit development).

## Architecture

**7 agents** in `.claude/agents/*.md`, each with:
- `executor` (fast tier) + `advisor` (stronger tier) — both Anthropic-served Claude models
- `integrity-hash-sha256` for agent integrity verification
- Frontmatter contract for model selection

**Security Panel** (`security-panel`) orchestrates a 3-stage pipeline writing to `/tmp/ai-security-panel/`:
```
requirements-agent → risk-analysis-agent → solutions-agent
```

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

## Agent Invocation

```bash
Agent(
  description: "Security audit of auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection, secret-leak, and authz bypass issues."
)
```

## Adding New Agents

Frontmatter required fields:
```yaml
---
name: my-agent
description: One-line purpose
executor: claude-sonnet-4-6
advisor: claude-opus-4-7
integrity-hash-sha256: SHA256:<hash>
tools: [Bash, Read, Write, ...]
skills: []
---
```
