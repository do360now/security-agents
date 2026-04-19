# Security Agents

**Defensive AI security team using Claude Code + Ollama cloud models.**

A hardened multi-agent system implementing an advisor pattern (fast executor + strong advisor) with defense-in-depth controls against AI-capable adversaries.

## Status

**22/22 red-team tests passing.** All mitigations from the 3-stage AI security panel implemented.

## Quick Start

```bash
git clone https://github.com/do360now/security-agents.git
cd security-agents
chmod +x setup-and-redteam.sh
./setup-and-redteam.sh
```

## What This Does

Runs a full defensive security suite:

1. **Red-team test suite** — 22 automated tests covering agent integrity, model allowlist, command injection, advisor sandboxing, config drift, kill switch, and more
2. **Agent verification** — SHA-256 hash verification of all agent frontmatter
3. **Model verification** — all Ollama models verified against allowlist
4. **Security incident response** — kill switch with <60s termination timeline

## Running Individual Agents

```bash
# Security panel (3-stage pipeline)
agent subagent_type=security-panel

# Vulnerability scanning
agent subagent_type=security-agent

# System diagnostics
agent subagent_type=system-health-agent

# Maintenance
agent subagent_type=maintenance-agent
```

## Key Security Controls

| Control | Implementation |
|---------|---------------|
| Agent integrity | SHA-256 frontmatter hashes verified on load |
| Model security | Allowlist with SHA-256 digests |
| Bash restrictions | `domain:localhost`, limited command set |
| Advisor sandbox | Output validated against contract |
| Config drift | `git diff HEAD` on every session |
| Inline script detection | CI/CD grep for dangerous `$(cmd)` patterns |
| Kill switch | `SECURITY_INCIDENT_RUNBOOK.md` — <60s termination |
| Audit logging | JSON Lines, 90-day retention, 5 event types |

## Repository Structure

```
├── setup-and-redteam.sh          # Bootstrap + run all tests
├── Makefile                      # make red-team-test / red-team-full
├── SECURITY_INCIDENT_RUNBOOK.md # Kill switch + incident response
├── AGENT_LOGGING_SCHEMA.md      # Audit log format reference
├── MODELS_ALLOWLIST.md          # Approved Ollama models
├── COMMAND_SAFETY_GUIDELINES.md # Safe Bash construction rules
├── ADVISOR_OUTPUT_CONTRACT.md   # Valid advisor response patterns
├── SKILL_VERSION_POLICY.md      # Skill version pinning policy
├── verify-*.sh                  # Verification scripts
├── detect-config-drift.sh       # Config tamper detection
├── pre-commit-inline-script-check.sh
├── validate-advisor-output.sh
├── .claude/
│   ├── agents/
│   │   ├── security-agent.md
│   │   ├── system-health-agent.md
│   │   ├── maintenance-agent.md
│   │   ├── requirements-agent.md
│   │   ├── risk-analysis-agent.md
│   │   ├── solutions-agent.md
│   │   └── security-panel.md
│   └── settings.local.json
└── CLAUDE.md                    # Full project documentation
```

## Models

All agents use Ollama **cloud** models (`:cloud` suffix — no local GPU):

| Model | Role |
|-------|------|
| `devstral-2:123b-cloud` | Primary executor, panel orchestrator |
| `devstral-small-2:24b-cloud` | Fast executor, security scanning |
| `glm-5.1:cloud` | Risk analysis, advisor |
| `minimax-m2.5:cloud` | Maintenance executor |
| `minimax-m2.7:cloud` | Alternative executor |
| `ministral-3:14b-cloud` | System health executor |
| `gemma4:31b-cloud` | System health advisor |

## Requirements

- `python3` — for JSON parsing in verification scripts
- `git` — repository operations
- `ollama` — model inference (cloud models)

## License

Internal use — security sensitive.
