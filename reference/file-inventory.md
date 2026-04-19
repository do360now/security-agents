# Reference — File Inventory

Every file in the repository and its purpose.

## Root Level

### Scripts

| File | Purpose |
|------|---------|
| `setup-and-redteam.sh` | Bootstrap + run all 22 red-team tests |
| `agent-logger.sh` | Audit logging wrapper (5 event types, JSON Lines) |
| `verify-all-agents.sh` | Verify SHA-256 frontmatter hash on all agents |
| `verify-model-digest.sh` | Verify Ollama model digest against allowlist |
| `verify-skill-versions.sh` | Check all agents for pinned skill versions |
| `validate-makefile-models.sh` | Verify all Makefile models are in allowlist |
| `validate-advisor-output.sh` | Validate advisor output against contract |
| `detect-config-drift.sh` | Detect unauthorized config changes (git diff) |
| `pre-commit-inline-script-check.sh` | Detect dangerous `$(curl\|wget\|python)` patterns |

### Configuration

| File | Purpose |
|------|---------|
| `MODELS_ALLOWLIST.md` | Approved Ollama models with SHA-256 digests |
| `SKILL_VERSION_POLICY.md` | Policy for pinning skill versions |
| `COMMAND_SAFETY_GUIDELINES.md` | Rules for safe Bash command construction |
| `ADVISOR_OUTPUT_CONTRACT.md` | Valid/invalid advisor response patterns |
| `AGENT_LOGGING_SCHEMA.md` | Audit log schema (JSON Lines, retention, rotation) |
| `Makefile` | `make red-team-test` / `make red-team-full` targets |

### Documentation

| File | Purpose |
|------|---------|
| `README.md` | Project overview (Diátaxis index) |
| `CLAUDE.md` | Documentation for Claude Code agents |
| `SECURITY_INCIDENT_RUNBOOK.md` | Kill switch + incident response (<60s) |

### Panel Outputs (not versioned)

Location: `/tmp/ai-security-panel/`

| File | Purpose |
|------|---------|
| `REQUIREMENTS.md` | Stage 1 output — concrete security requirements |
| `RISK_ANALYSIS.md` | Stage 2 output — attack vectors and risks |
| `RED_TEAM_TESTS.md` | Stage 2 output — 22 red-team tests |
| `SOLUTIONS.md` | Stage 3 output — mitigations mapped to tests |
| `MITIGATION_ROADMAP.md` | Stage 3 output — prioritized implementation plan |
| `PANEL_REPORT.md` | Executive summary combining all stages |

---

## `.claude/` Directory

### Agents

| File | Purpose |
|------|---------|
| `.claude/agents/security-agent.md` | Vulnerability scanning agent |
| `.claude/agents/system-health-agent.md` | Diagnostics agent |
| `.claude/agents/maintenance-agent.md` | Updates and cleanup agent |
| `.claude/agents/requirements-agent.md` | Requirements generation agent |
| `.claude/agents/risk-analysis-agent.md` | Risk analysis + red-team tests |
| `.claude/agents/solutions-agent.md` | Mitigation design agent |
| `.claude/agents/security-panel.md` | 3-stage pipeline orchestrator |
| `.claude/agents/CLAUDE.md` | Agent directory documentation |
| `.claude/agents/README.md` | Agent directory README |

### Settings

| File | Purpose |
|------|---------|
| `.claude/settings.local.json` | Agent permissions (Bash restrictions, tool allowlist) |

---

## Diátaxis Structure

```
tutorial/           Learning-oriented — step-by-step introduction
  getting-started.md

how-to/              Task-oriented — accomplish specific goals
  run-red-team-tests.md
  respond-to-incident.md
  add-new-agent.md

reference/           Information-oriented — look up facts
  README.md
  agent-roster.md
  file-inventory.md
  verification-scripts.md
  command-reference.md

explanation/         Understanding-oriented — why things are designed as they are
  advisor-pattern.md
  security-architecture.md
  threat-model.md
```
