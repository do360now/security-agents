# Tutorial — Getting Started

A step-by-step introduction to the security agents system. By the end you'll have run the full red-team test suite and invoked your first security agent.

## Prerequisites

- `git` — to clone the repository
- `python3` — for JSON parsing in verification scripts
- `ollama` — for model inference (cloud models, no GPU needed)
- Claude Code installed

---

## Step 1 — Clone and Verify

```bash
git clone https://github.com/do360now/security-agents.git
cd security-agents
chmod +x setup-and-redteam.sh
```

The repository contains:
- **7 agents** in `.claude/agents/`
- **22 automated tests** that verify security controls
- **Verification scripts** for hashes, models, and config

---

## Step 2 — Run the Red-Team Test Suite

```bash
./setup-and-redteam.sh
```

This runs all 22 tests in sequence:

| Test | What it Checks |
|------|---------------|
| RT-001 | SHA-256 frontmatter hash on every agent |
| RT-002 | All Ollama models in the allowlist |
| RT-003 | Advisor calls use `cat <<'EOF'` scoping |
| RT-004 | Advisor output validated against contract |
| RT-005 | Each agent uses different models for executor/advisor |
| RT-006 | Git repository exists and has commits |
| RT-007 | Config drift monitoring on startup |
| RT-008 | Bash restricted to localhost |
| RT-009 | Makefile models verified |
| RT-010/017 | No dangerous command substitutions |
| RT-011 | Behavioral anomaly detection documented |
| RT-012 | Kill switch runbook exists |
| RT-013 | Audit logging infrastructure |
| RT-014 | Pipeline stage validation |
| RT-015 | Output durability (write before advisor) |
| RT-016 | Model provenance attestation |
| RT-018 | All skills version-pinned |
| RT-019 | Same-model chain broken |
| RT-020 | Agent hijack chain mitigated |
| RT-021 | Advisor manipulation chain mitigated |
| RT-022 | Infrastructure weaponization chain mitigated |

Expected output:
```
RESULTS: 21 PASS, 0 FAIL (of 22 tests)
[PASS]  All 22 tests passing — system is hardened.
```

---

## Step 3 — Invoke a Security Agent

Use the `Agent` tool with the `subagent_type` and a `prompt`:

```bash
# Vulnerability scanning
Agent(subagent_type="security-agent", prompt="Scan src/auth/ for SQL injection and authz bypass")

# System diagnostics
Agent(subagent_type="system-health-agent", prompt="CPU and memory overview — look for zombies")

# Maintenance
Agent(subagent_type="maintenance-agent", prompt="Clean temp files and check for outdated dependencies")
```

Each agent uses the **advisor pattern**: a fast executor drives the work, and a stronger advisor is consulted at three moments:
1. After initial recon (before committing to a hypothesis)
2. When stuck (approach not converging)
3. Before declaring done (output on disk first)

---

## Step 4 — Run the Security Panel

The security panel is a 3-stage pipeline that models how an AI-capable attacker (e.g., Mythos-class) would approach your system, then designs defenses:

```bash
Agent(subagent_type="security-panel", prompt="
A Node.js Express API with JWT authentication and PostgreSQL.
Focus on: authnz, input validation, dependency vulnerabilities.
Threat: autonomous AI model that chains zero-days.
")
```

The panel runs three stages:

```
Stage 1: requirements-agent  →  REQUIREMENTS.md
Stage 2: risk-analysis-agent →  RISK_ANALYSIS.md + RED_TEAM_TESTS.md
Stage 3: solutions-agent   →  SOLUTIONS.md + MITIGATION_ROADMAP.md
```

Output goes to `/tmp/ai-security-panel/`.

---

## Step 5 — Understand the Results

After running agents or the panel, check the key outputs:

- **`/tmp/ai-security-panel/REQUIREMENTS.md`** — What the system must maintain to be secure
- **`/tmp/ai-security-panel/RISK_ANALYSIS.md`** — How an attacker would violate each requirement
- **`/tmp/ai-security-panel/RED_TEAM_TESTS.md`** — Tests that fail if the vulnerability exists
- **`/tmp/ai-security-panel/SOLUTIONS.md`** — Specific mitigations mapped to each test

---

## What's Next?

- **[How to: Run the test suite](./how-to/run-red-team-tests.md)** — Different ways to run tests
- **[How to: Respond to an incident](./how-to/respond-to-incident.md)** — Kill switch procedure
- **[How to: Add a new agent](./how-to/add-new-agent.md)** — Extend the system
- **[Reference: Agent roster](./reference/agent-roster.md)** — All agents and their models
- **[Explanation: The advisor pattern](./explanation/advisor-pattern.md)** — Why the advisor pattern works
