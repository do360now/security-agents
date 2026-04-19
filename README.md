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

All agents are invoked via the `Agent` tool with `subagent_type`:

```bash
# Security panel (3-stage pipeline)
Agent(subagent_type="security-panel", prompt="[threat/system description]")

# Vulnerability scanning
Agent(subagent_type="security-agent", prompt="Scan src/auth/ for injection and authz issues")

# System diagnostics
Agent(subagent_type="system-health-agent", prompt="CPU and memory overview — look for runaway processes")

# Maintenance
Agent(subagent_type="maintenance-agent", prompt="Clean temp files and check for outdated dependencies")
```

## Advisor Pattern

Each agent pairs a **fast executor** with a **stronger advisor** consulted at three moments:
1. **After initial recon** — before committing to a hypothesis
2. **When stuck** — approach not converging after retries
3. **Before declaring done** — output on disk first (a timeout mid-advice must not lose work)

Example advisor call from any agent:
```bash
ollama run <advisor-model>:cloud "$(cat <<'EOF'
You are a security advisor. Respond in under 100 words, enumerated steps only.
<task>[current task]</task>
<transcript>[what the agent has found so far]</transcript>
What should the agent do next?
EOF
)"
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
├── agent-logger.sh               # Audit logging wrapper
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

## Security Panel (3-Stage Pipeline)

Run via `Agent(subagent_type="security-panel")` with a threat/system description:

```
Stage 1: requirements-agent  →  REQUIREMENTS.md
Stage 2: risk-analysis-agent →  RISK_ANALYSIS.md + RED_TEAM_TESTS.md
Stage 3: solutions-agent   →  SOLUTIONS.md + MITIGATION_ROADMAP.md
```

Output goes to `/tmp/ai-security-panel/`. The panel models how an autonomous AI attacker (e.g., Mythos-class) would approach your system, then designs defenses accordingly.

## Implementation Phases

All mitigations from the AI security panel have been implemented:

| Phase | Items | Status |
|-------|-------|--------|
| **P0** | Agent hash integrity (RT-001), model allowlist (RT-002), git signing (RT-006), bash domain restrictions (RT-008), advisor scoping (RT-003/004) | ✅ Complete |
| **P1** | Config drift monitoring (RT-007/010), anomaly detection (RT-011), kill switch (RT-012), pipeline validation (RT-014), output durability (RT-015) | ✅ Complete |
| **P2** | Inline script detection (RT-017), skill version pinning (RT-018), model provenance (RT-016), model diversity (RT-005/019) | ✅ Complete |
| **P3** | Audit logging infrastructure (RT-013) | ✅ Complete |

**22/22 red-team tests passing.**

## Requirements

- `python3` — for JSON parsing in verification scripts
- `git` — repository operations
- `ollama` — model inference (cloud models)

## License

Internal use — security sensitive.
