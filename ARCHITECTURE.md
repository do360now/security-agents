# Architecture Overview

**Purpose**: Explain how the security-agents system works end-to-end — agents, skills, the advisor pattern, pipeline orchestration, and security controls.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Claude Code (Host Agent)                     │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │ security-     │    │ system-      │    │ security-   │       │
│  │ agent         │    │ health-agent │    │ panel       │       │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘       │
│         │                   │                   │                │
│         ▼                   ▼                   ▼                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              .claude/skills/ (46 skills)               │    │
│  │  secure-code-review  owasp-top-10-web  prompt-injection │    │
│  │  api-security  threat-modeling  cve-triage  ...       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           ▲                                      │
│                           │ skills auto-invoked by context       │
│  ┌───────────────────────┴─────────────────────────────────┐ │
│  │              Advisor Pattern (ollama run)                  │ │
│  │  Executor (fast model) ──► Advisor (stronger model)        │ │
│  │  minimax-m2.5:cloud ──► devstral-2:123b:cloud             │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Agents

Agents are **Markdown files with YAML frontmatter** in `.claude/agents/`. Each agent defines:
- `executor` — fast model for most work
- `advisor` — stronger model consulted at decision points
- `tools` — what the agent can do
- `skills` — which skills to auto-load (pinned to version)

**7 agents currently defined:**

| Agent | Executor | Advisor | Role |
|-------|----------|---------|------|
| `security-agent` | devstral-small-2:24b | glm-5.1:cloud | Vulnerability scanning + code review |
| `system-health-agent` | ministral-3:14b | gemma4:31b | Process/resource diagnostics |
| `maintenance-agent` | minimax-m2.5:cloud | devstral-2:123b | System cleanup, updates |
| `requirements-agent` | devstral-2:123b | devstral-2:123b | Generate security requirements from threat intel |
| `risk-analysis-agent` | glm-5.1:cloud | glm-5.1:cloud | Attack enumeration + red-team test generation |
| `solutions-agent` | devstral-small-2:24b | glm-5.1:cloud | Defensive solution design |
| `security-panel` | devstral-2:123b | devstral-small-2:24b | Orchestrates the 3-stage pipeline |

### 2. Skills

Skills are **framework-grounded guidance files** in `.claude/skills/<name>/SKILL.md`. They contain:
- Step-by-step processes grounded in OWASP, NIST, CVSS, etc.
- Detection patterns (`Grep`/`Read` commands)
- Finding templates mapped to CWE identifiers
- `injection-hardened: true` — protects against prompt injection

**46 skills available**, organized by domain:
- **appsec**: secure-code-review, owasp-top-10-web, api-security, threat-modeling, dependency-scanning, dast-config, sast-config, pipeline-security, secrets-management
- **ai-security**: prompt-injection, agent-security, llm-top-10, ai-data-privacy, model-supply-chain, agentic-top-10
- **cloud**: aws-review, azure-review, gcp-review, container-security, iac-security
- **compliance**: nist-csf-assessment, soc2-gap, hipaa-review, iso27001-gap, pci-dss-review
- **identity**: iam-review, access-review, rbac-design, privileged-access, zero-trust-assessment
- **incident-response**: ir-playbook, containment, forensics-checklist, post-incident-review
- **network**: firewall-review, dns-security, segmentation
- **secops**: alert-triage, detection-engineering, log-analysis, siem-rules
- **vuln-management**: cve-triage, patch-prioritization, sbom-analysis, scanner-tuning

### 3. The Advisor Pattern

The executor does the work. The advisor is consulted at 3 moments:

```
1. After initial recon (before committing to a plan)
   ┌────────────────────────────────────────────┐
   │  Executor: "here's what I found"           │
   │  Advisor: "here's what to focus on next"   │
   └────────────────────────────────────────────┘

2. When stuck (approach not converging)
   ┌────────────────────────────────────────────┐
   │  Executor: "I've tried X, Y, Z — still    │
   │            finding nothing"               │
   │  Advisor: "try tracing the auth flow      │
   │            instead of the data flow"      │
   └────────────────────────────────────────────┘

3. Before declaring done (output on disk first)
   ┌────────────────────────────────────────────┐
   │  Executor: "here are my findings — does    │
   │            this severity ranking hold?"    │
   │  Advisor: "yes, but you're missing an       │
   │            exploit chain between REQ-003   │
   │            and REQ-007"                   │
   └────────────────────────────────────────────┘
```

**Security controls on advisor calls:**
- Uses `cat <<'EOF'` (quoted heredoc) — prevents variable expansion
- Output validated by `validate-advisor-output.sh` — rejects shell metacharacters, raw bash, file redirection, external URLs

### 4. Security Panel Pipeline (3-Stage)

The `security-panel` orchestrates three stages:

```
Stage 1: REQUIREMENTS AGENT        Stage 2: RISK ANALYSIS AGENT     Stage 3: SOLUTIONS AGENT
Input: threat intelligence     →    Input: REQUIREMENTS.md          →  Input: REQUIREMENTS.md
Output: REQUIREMENTS.md              + target system                 RISK_ANALYSIS.md
                                     Output: RISK_ANALYSIS.md        RED_TEAM_TESTS.md
                                     + RED_TEAM_TESTS.md             Output: SOLUTIONS.md
                                                                       + MITIGATION_ROADMAP.md
```

**Stage validation rules:**
- Each stage validates prior output exists and has expected schema before proceeding
- Output must be written to disk BEFORE calling the advisor for the next stage
- Schema validation via grep for expected headers (e.g., `## REQ-[0-9]+:`, `## RISK-[0-9]+:`)

### 5. Skill Auto-Invocation

When an agent starts work, it detects the target type and loads the relevant skill:

```bash
# Context detection
TARGET_TYPE=$(file target/ | tr ',' '\n' | grep -iE "rest|web|llm|cloud|container" | head -1)

# Skill selection
case "$TARGET_TYPE" in
  api|REST|GraphQL)  SKILL_NAME="api-security" ;;
  web|HTML|JS)        SKILL_NAME="owasp-top-10-web" ;;
  LLM|RAG|Prompt)    SKILL_NAME="prompt-injection" ;;
  cloud|Terraform)   SKILL_NAME="iac-security" ;;
  container|Docker)  SKILL_NAME="container-security" ;;
  *)                 SKILL_NAME="secure-code-review" ;;
esac

# Load skill guidance
cat .claude/skills/$SKILL_NAME/SKILL.md
```

This is documented in `SKILL_AUTO_INVOKE.md`.

### 6. Feedback Loop

The `feedback-loop.sh` script routes test failures back to the skill that should have prevented them:

```
make red-team-test
        ↓
Parse FAIL lines from test output
        ↓
Map test ID → responsible skill
        ↓
Write to /tmp/ai-security-panel/skill-feedback.jsonl
        ↓
Report which skills need review
```

Example failure mapping:
- RT-010 failure → `secure-code-review` (should detect exec() injection)
- RT-017 failure → `secure-code-review` (should detect inline script injection)
- Model diversity failure → `(infrastructure)` (agent config issue)

---

## Security Controls

Every agent and skill file has a SHA256 integrity hash. If a file is modified:
1. Hash recomputed by `verify-all-agents.sh` or `verify-all-skills.sh`
2. Mismatch detected → test fails
3. Feedback loop flags which skill/agent needs review

```
File modified → Hash mismatch → Test fails → Feedback loop flags skill → Fix + recompute hash → Test passes
```

**Control chain:**
- **Agent hijack chain**: git history + agent hash + model allowlist
- **Advisor manipulation chain**: heredoc scoping (`cat <<'EOF'`) + advisor output sandbox + model diversity
- **Infrastructure weaponization chain**: Bash domain restriction + model allowlist + config drift detection

---

## File Reference

| File | Purpose |
|------|---------|
| `.claude/agents/*.md` | Agent definitions with executor/advisor, tools, skills |
| `.claude/skills/*/SKILL.md` | 46 framework-grounded skill files |
| `SKILL_AUTO_INVOKE.md` | Context-to-skill mapping for auto-invocation |
| `CLAUDE.md` | Per-file guidance for Claude Code agents |
| `verify-all-agents.sh` | Verify agent SHA256 hashes |
| `verify-all-skills.sh` | Verify skill SHA256 hashes |
| `feedback-loop.sh` | Route red-team failures to skills needing updates |
| `validate-advisor-output.sh` | Validate advisor responses against contract |
| `detect-config-drift.sh` | Alert if settings.local.json is modified |
| `SKILL_VERSION_POLICY.md` | Policy: pin skill versions, no floating refs |

---

## Quick Start

**To run a security review:**
```bash
# Using Agent tool (recommended)
Agent(description="Security audit of auth module",
      subagent_type="security-agent",
      prompt="Scan src/auth/ for injection, secret-leak, and authz bypass issues. Assume AI-assisted attackers will target credentials and auth entry points first.")

# Or using the pipeline
Agent(description="Full security pipeline",
      subagent_type="security-panel",
      prompt="Threat: AI-accelerated offense — autonomous model finds and chains CVEs at scale in this codebase.")
```

**To verify the system:**
```bash
./verify-all-agents.sh   # Verify agent hashes
./verify-all-skills.sh    # Verify skill hashes
make red-team-test        # Run quick pass/fail summary
./feedback-loop.sh        # Route failures to skills needing updates
```

**To add a new skill:**
1. Copy skill from SecuritySkills to `.claude/skills/<name>/SKILL.md`
2. Add `integrity-hash-sha256` to frontmatter
3. Update agent's skills array with `name: <name>, version: "<version>"`
4. Verify: `./verify-all-skills.sh`

---

## Design Principles

1. **Advisor over automation** — executor acts, advisor guides at decision points
2. **Skills as first-class files** — not embedded in agents, versioned alongside
3. **Integrity by hashing** — frontmatter hash excludes the hash field itself (verified by the same pattern as the file)
4. **Durable output first** — write findings to disk before calling the advisor
5. **Explicit over implicit** — model diversity, bash restrictions, skill versions all declared in frontmatter
6. **AI-accelerated offense era** — assume attackers have autonomous AI capable of finding and chaining vulnerabilities at machine scale; prioritize patch velocity, exploitability reduction, and credential hardening over pattern density

---

## Threat Model

The system is designed against a threat landscape where AI models dramatically reduce the time and skill required to find and exploit vulnerabilities. Key assumptions:

- **Patch-to-exploit window collapsing**: AI-assisted patch reversal means a public patch can become a working exploit within days. Prioritize CISA KEV catalog and EPSS scoring > 6.0.
- **Credential discovery at scale**: AI-assisted static analysis finds hardcoded secrets, API keys, and service account credentials as a first-pass scan — treat exposed credentials as critical findings.
- **Autonomous vulnerability finding**: Within the next 24 months, AI models will autonomously find and chain CVEs into working exploits at scale. Codebases that were "secure enough" with human attackers need hardening for AI-speed attackers.
- **Exploitability over prevalence**: A single high-severity exploitable path is more urgent than many low-severity patterns. AI-capable attackers will find and chain the high-severity paths first.

**Defensive priorities derived from threat model:**
- Patch critical vulnerabilities within 24 hours of exploit availability
- Replace long-lived secrets with hardware-bound credentials or short-lived tokens
- Adopt zero trust architecture — assume breach, verify explicitly, least privilege
- Run autonomous red-team against your own perimeter before AI-capable external attackers do
- Audit for exploit primitives (format string, TOCTOU, type confusion) with higher urgency
- Log AI-driven reconnaissance signals (atypical source IPs, request patterns, behavioral anomalies)
