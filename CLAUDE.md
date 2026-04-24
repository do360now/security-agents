# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a defensive AI security system using the **advisor pattern** with Ollama models: a fast local executor drives the loop, a stronger cloud advisor is consulted at strategic decision points. The system helps defenders respond to AI-capable adversaries (e.g., Mythos-class autonomous exploit development).

## Architecture

**7 agents** in `.claude/agents/*.md`, each with:
- `executor` (local, fast) + `advisor` (cloud, strong reasoning)
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

# Run individual agents (mixed local + cloud setup)
make start-security-agent   # Executor: qwen2.5:3b, Advisor: devstral-small-2:24b-cloud
make start-requirements-agent
make start-solutions-agent

# Verify controls
./verify-all-agents.sh
./validate-makefile-models.sh
./validate-advisor-output.sh
./verify-skill-versions.sh
```

## Critical Security Controls

1. **Advisor Output Validation** (MANDATORY before acting on advisor responses):
   - Run `validate-advisor-output.sh` — rejects raw bash, shell metacharacters, redirection
   - Advisor responses must be enumerated steps only, no compound commands
   - See `ADVISOR_OUTPUT_CONTRACT.md` for the full contract
   - **OWASP ASI01 (Prompt Injection)**: defended by this validation

2. **Model Allowlist**: Only models documented in `MODELS_ALLOWLIST.md` with SHA256 digests may be used

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
executor: <model>
advisor: <model>
integrity-hash-sha256: SHA256:<hash>
tools: [Bash, Read, Write, ...]
skills: []
---
```
