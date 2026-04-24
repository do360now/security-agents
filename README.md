# AI Security Panel

A defensive AI security system that helps defenders respond to AI-capable adversaries. It uses a **dual-model advisor pattern**: a fast local executor handles the operational loop, while a stronger cloud-based advisor provides strategic guidance at key decision points.

## Overview

This system is designed to help security teams:
- Analyze code for vulnerabilities
- Generate security requirements from threat intelligence
- Perform risk analysis on requirements
- Design defensive solutions and mitigations

## Quick Start

```bash
# Run the full security panel pipeline
make start-security-agent

# Run individual agents
make start-requirements-agent
make start-solutions-agent

# Verify all agents are working correctly
./verify-all-agents.sh

# Run the red team test suite (quick check)
make red-team-test

# Run full red team tests (detailed output)
make red-team-full
```

## Architecture

The system uses 7 specialized agents, each with two components:

| Component | Description |
|-----------|-------------|
| **Executor** | Local Ollama model for real-time operations |
| **Advisor** | Cloud model consulted for strategic decisions |

The **Security Panel** orchestrates a three-stage pipeline:
```
Requirements Agent → Risk Analysis Agent → Solutions Agent
```

Findings are written to `/tmp/ai-security-panel/` for durability before consulting the advisor.

## Available Agents

| Agent | Executor | Advisor | Purpose |
|-------|----------|---------|---------|
| `security-agent` | qwen2.5:3b | devstral-small-2:24b-cloud | Vulnerability analysis |
| `requirements-agent` | qwen2.5:7b | devstral-2:123b-cloud | Generate requirements from threats |
| `risk-analysis-agent` | glm-5.1:cloud | devstral-2:123b-cloud | Risk analysis + red team tests |
| `solutions-agent` | qwen2.5:3b | devstral-small-2:24b-cloud | Design mitigations |
| `security-panel` | devstral-2:123b-cloud | devstral-small-2:24b-cloud | Orchestrates 3-stage pipeline |
| `system-health-agent` | qwen2.5:3b | gemma4:31b-cloud | Monitor system health |
| `maintenance-agent` | qwen2.5:3b | devstral-2:123b-cloud | System maintenance |

## Security Controls

### 1. Advisor Output Validation (OWASP ASI01)
Before acting on advisor responses, the system validates outputs to reject:
- Raw bash commands
- Shell metacharacters (`;`, `|`, `&`, etc.)
- Redirection operators (`>`, `<`, `>>`)
- Compound commands

This is enforced by `validate-advisor-output.sh`. Run it after any advisor interaction. See `ADVISOR_OUTPUT_CONTRACT.md` for details.

**OWASP Agentic Top 10 (2026) Alignment:**
- **ASI01 Prompt Injection**: Defended by advisor output validation
- **ASI02 Excessive Agency**: Agent tools explicitly declared; system-health-agent monitors for scope violations

### 2. Model Allowlist
Only models documented in `MODELS_ALLOWLIST.md` with verified SHA256 digests may be used. This prevents unauthorized model substitution.

To verify a model:
```bash
./verify-model-digest.sh <model-name>:cloud
```

### 3. Agent Integrity Verification
Each agent has an `integrity-hash-sha256` field. Run verification:
```bash
./verify-all-agents.sh
```

### 4. Kill Switch
If agents are compromised, refer to `SECURITY_INCIDENT_RUNBOOK.md` for the full termination procedure.

**Emergency termination (single command):**
```bash
pkill -9 -f "ollama" && pkill -9 -f "claude" && echo "All agent processes killed"
```

### 5. Output Durability
Findings are written to disk immediately, before consulting the advisor. This ensures work is preserved even if the session drops.

### 6. Audit Logging
All agent sessions log to `/tmp/ai-security-panel/session-log.jsonl` with timestamp, agent, action, target, advisorCalled, and validationPassed. See `SECURITY_INCIDENT_RUNBOOK.md` for schema details.

### 7. Configuration Drift Detection
Monitor for unauthorized changes to agent configurations:
```bash
./detect-config-drift.sh
```

### 8. EU AI Act Compliance (Aug 2026)
Full requirements take effect **August 2, 2026** — requires documented adversarial testing for high-risk AI systems. This system's red team test suite, advisor output validation, and audit logging constitute the required documented testing mechanisms.

## Red Team Test Suite

The system includes automated red team tests that verify security controls:

```bash
make red-team-test      # Quick pass/fail summary
make red-team-full      # Detailed per-test output
```

### Test Categories

| Test | Description |
|------|-------------|
| RT-001 | Agent Integrity (SHA-256 hash) |
| RT-002 | Model Allowlist Enforcement |
| RT-004 | Advisor Output Sandbox |
| RT-005 | Model Diversity (executor vs advisor must differ) |
| RT-006 | Git Repository |
| RT-007 | Config Drift Monitoring |
| RT-008 | Bash Domain Restrictions |
| RT-010 | Command Injection (inline scripts) |
| RT-012 | Kill Switch Runbook |
| RT-013 | Audit Logging Infrastructure |
| RT-014/015 | Pipeline Validation + Output Durability |
| RT-016 | Model Provenance Attestation |
| RT-017 | Inline Script Detection (CI/CD) |
| RT-018 | Skill Version Pinning |
| RT-020 | Agent Hijack Chain (git + hash + allowlist) |
| RT-021 | Advisor Manipulation Chain |
| RT-022 | Infrastructure Weaponization |
| RT-023 | Prompt Injection Defense (OWASP ASI01) |
| RT-024 | Excessive Agency Prevention (OWASP ASI02) |
| RT-025 | Context Poisoning Defense |
| RT-026 | Memory Segregation |
| RT-027 | EU AI Act Readiness (Aug 2026 deadline) |
| RT-028 | Least Privilege Access |
| RT-029 | Behavioral Monitoring |
| RT-030 | Garak/PyRIT Availability |

## Tools

The following external tools complement this system:

| Tool | Purpose |
|------|---------|
| **Garak** (NVIDIA) | Prompt injection and vulnerability probes (37+ detection modules) |
| **PyRIT** (Microsoft) | Multi-turn attack orchestration for red team testing |
| **LLM Guard** | Open-source input/output scanning for production deployments |
| **Promptfoo** | Maps red team tests to OWASP, NIST, MITRE ATLAS compliance |

Install: `pip install garak pyrit llm-guard promptfoo`

## Verification Scripts

```bash
./verify-all-agents.sh          # Verify all agent hashes
./verify-model-digest.sh        # Verify model SHA-256 digests
./validate-makefile-models.sh   # Verify Makefile model references
./validate-advisor-output.sh    # Validate advisor output contract
./verify-skill-versions.sh      # Verify skill versions
./detect-config-drift.sh       # Detect unauthorized config changes
```

## Adding New Agents

New agents must include the following frontmatter:

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

## Approved Models

### Local Models (GTX 1070 compatible — 8GB VRAM)
- `qwen2.5:3b` — Fast executor for security-agent, solutions-agent
- `qwen2.5:7b` — Stronger executor for requirements-agent
- `llama3.2:3b` — Alternative fast executor
- `mistral:7b` — Alternative 7B executor
- `codellama:7b` — Code-focused executor

### Cloud Models (advisors)
- `devstral-2:123b-cloud` — Requirements agent advisor
- `devstral-small-2:24b-cloud` — Security/solutions advisor
- `glm-5.1:cloud` — Risk analysis advisor
- `minimax-m2.5:cloud` — Maintenance agent
- `minimax-m2.7:cloud` — Alternative executor
- `ministral-3:14b-cloud` — System health advisor
- `gemma4:31b-cloud` — System health advisor

## Key Files

| File | Purpose |
|------|---------|
| `ADVISOR_OUTPUT_CONTRACT.md` | Full contract for advisor output validation |
| `MODELS_ALLOWLIST.md` | List of permitted models with SHA256 digests |
| `SECURITY_INCIDENT_RUNBOOK.md` | Kill switch and incident response procedures |
| `COMMAND_SAFETY_GUIDELINES.md` | Safety guidelines for command execution |
| `SKILL_VERSION_POLICY.md` | Skill version pinning policy |
| `.claude/agents/` | Agent definitions with frontmatter |

## Agent Invocation

To invoke an agent from code:

```bash
Agent(
  description: "Security audit of auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection, secret-leak, and authz bypass issues."
)
```
