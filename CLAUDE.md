# CLAUDE.md — Security Agents Repository

This repository contains a defensive AI security team built with Claude Code and Ollama cloud models.

## What This Is

A hardened multi-agent security system using Anthropic's **advisor pattern** (fast executor + strong advisor) with open-weight Ollama models. The system implements:

- **7 specialized agents** for security, health, maintenance, and panel operations
- **3-stage AI security panel** (requirements → risk analysis → solutions)
- **22 automated red-team tests** (all passing)
- **Defense-in-depth controls** against AI-capable attackers (Mythos-class)

## Quick Start

```bash
# Clone and run the full red-team test suite
git clone https://github.com/do360now/security-agents.git
cd security-agents
chmod +x setup-and-redteam.sh
./setup-and-redteam.sh

# Run the security panel (3-stage pipeline)
agent subagent_type=security-panel

# Run individual agents
agent subagent_type=security-agent     # vulnerability scanning
agent subagent_type=system-health-agent # diagnostics
agent subagent_type=maintenance-agent  # updates & cleanup
```

## Key Files

| File | Purpose |
|------|---------|
| `setup-and-redteam.sh` | Bootstrap + run all 22 red-team tests |
| `Makefile` | `make red-team-test` / `make red-team-full` |
| `SECURITY_INCIDENT_RUNBOOK.md` | Kill switch + incident response (<60s) |
| `AGENT_LOGGING_SCHEMA.md` | Audit log format (JSON Lines, 90-day retention) |
| `MODELS_ALLOWLIST.md` | Approved Ollama models with SHA-256 digests |
| `COMMAND_SAFETY_GUIDELINES.md` | Safe Bash command construction rules |
| `ADVISOR_OUTPUT_CONTRACT.md` | Valid/invalid advisor response patterns |
| `verify-*.sh` scripts | Hash verification, model allowlist, config drift |

## Agent Roster

| Agent | Executor | Advisor | Role |
|-------|----------|---------|------|
| `security-agent` | devstral-small-2:24b | devstral-2:123b | Vulnerability scanning, code review |
| `system-health-agent` | ministral-3:14b | gemma4:31b | Process/resource diagnostics |
| `maintenance-agent` | minimax-m2.5 | devstral-2:123b | Updates, cleanup, optimization |
| `requirements-agent` | devstral-2:123b | glm-5.1 | Generate security requirements |
| `risk-analysis-agent` | glm-5.1 | devstral-2:123b | Attack vectors + red-team tests |
| `solutions-agent` | devstral-small-2:24b | glm-5.1 | Mitigation design |
| `security-panel` | devstral-2:123b | devstral-small-2:24b | 3-stage pipeline orchestrator |

All models are Ollama **cloud** models (`:cloud` suffix) — no local GPU required.

## Architecture

```
                    security-panel (orchestrator)
                           |
           +---------------+----------------+
           |               |                |
    requirements-agent  risk-analysis  solutions-agent
    (Stage 1)          -agent (Stage 2)  (Stage 3)
           |               |                |
           v               v                v
    REQUIREMENTS.md   RISK_ANALYSIS.md  SOLUTIONS.md
                      RED_TEAM_TESTS.md MITIGATION_ROADMAP
```

## Red-Team Test Suite

```bash
./setup-and-redteam.sh           # Full suite (all 22 tests)
make red-team-test                # Quick pass/fail summary
make red-team-full                # Verbose per-test output
```

Current status: **22/22 PASS**

## Security Controls

- SHA-256 frontmatter integrity hashes on all agents
- Model allowlist with digest verification
- Bash domain-restricted to localhost
- Advisor I/O scoped via `cat <<'EOF'` (no variable expansion)
- Advisor output validated against documented contract
- Config drift monitoring on every session start
- Inline script detection (CI/CD check)
- Skill version pinning (no floating versions)
- Kill switch runbook (<60s termination)
- Audit logging infrastructure (JSON Lines, 90-day retention)

## Advisor Pattern Rules

1. **After initial recon** — after file reads and listing commands, before substantive work
2. **When stuck** — recurring errors, approach not converging
3. **Before declaring done** — output on disk first, so a timeout mid-advice doesn't lose work

## Permissions

Agents require these permissions in `.claude/settings.local.json`:
- `Bash(domain:localhost,allowed-commands:[...])` — restricted to localhost
- `Read`, `Write`, `Edit`, `Grep`, `Glob` — file operations
- `WebFetch(domain:ollama.com)` — advisor model calls only

## Adding Agents

Frontmatter contract:
```yaml
---
name: my-agent
description: One-line purpose
integrity-hash-sha256: SHA256:<run ./verify-all-agents.sh after creating>
executor: <model-name>:cloud
advisor: <different-model-name>:cloud
tools:
  - name: Bash
  - name: Read
skills: []
---
```

Body should specify: responsibilities, advisor-call timing, and example `ollama run` prompts.
