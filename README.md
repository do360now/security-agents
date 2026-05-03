# AI Security Panel

A defensive AI security system that helps defenders respond to AI-capable adversaries. It uses a **dual-model advisor pattern** on Anthropic's Claude family: a faster executor (Haiku 4.5 / Sonnet 4.6) handles the operational loop, while a stronger advisor (Sonnet 4.6 / Opus 4.6 / Opus 4.7) provides strategic guidance at key decision points.

Operator workflows: see `WORKFLOW.md`.

## Overview

This system is designed to help security teams:
- Analyze code for vulnerabilities
- Generate security requirements from threat intelligence
- Perform risk analysis on requirements
- Design defensive solutions and mitigations

## Quick Start

```bash
# Run a defensive panel via the advisor-pattern pipeline (Round 4/5, recommended)
panel/run_stage.sh requirements   /tmp/ai-security-panel/<TARGET>/ "<threat + target description>"
panel/run_stage.sh risk-analysis  /tmp/ai-security-panel/<TARGET>/ "<task>"
panel/run_stage.sh solutions      /tmp/ai-security-panel/<TARGET>/ "<task>"

# Run an offensive (red-team) panel — same wrapper, attack-scenarios stage first
panel/run_stage.sh attack-scenarios /tmp/ai-security-panel/red-team/<TARGET>/ "<target description>"
panel/run_stage.sh risk-analysis    /tmp/ai-security-panel/red-team/<TARGET>/ "<task>"
panel/run_stage.sh solutions        /tmp/ai-security-panel/red-team/<TARGET>/ "<task>"

# Show per-agent model pairing and launch command
make start-security-agent
make start-requirements-agent
make start-solutions-agent

# Launch Claude Code on a specific tier
make start-opus-4-7
make start-sonnet-4-6
make start-haiku-4-5

# Verify all agents are working correctly
./verify-all-agents.sh

# Run the red team test suite
make red-team-test      # Quick pass/fail summary
make red-team-full      # Detailed per-test output
```

Each `panel/run_stage.sh` call writes three durable artifacts: `<STAGE>.json` (schema-validated), `<STAGE>.md` (rendered), `<STAGE>_SUMMARY.txt` (model's brief). See `WORKFLOW.md` for end-to-end runbooks.

## Architecture

The system uses 11 specialized agents, each with two components:

| Component | Description |
|-----------|-------------|
| **Executor** | Faster Claude tier (Haiku 4.5 or Sonnet 4.6) driving the agent's loop |
| **Advisor** | Stronger Claude tier (Sonnet 4.6 / Opus 4.6 / Opus 4.7) consulted at decision points |

Two orchestrators run three-stage pipelines that share Stage 2 and Stage 3:

**Security Panel** (defensive, starts from policy):
```
Requirements Agent → Risk Analysis Agent → Solutions Agent
                       outputs → /tmp/ai-security-panel/
```

Stage 2 fans out one `risk-analysis-agent` subagent per REQ-* item (in parallel) when 4+ requirements exist and the panel runs as the main session. See `WORKFLOW.md` section 6.

**Red Team Panel** (offensive, starts from adversary behavior):
```
ARES Agent → Risk Analysis Agent → Solutions Agent
                       outputs → /tmp/ai-security-panel/red-team/
```

Stage 2 fans out one `risk-analysis-agent` subagent per ATK-* item (in parallel) when 4+ scenarios exist and the panel runs as the main session.

Both panels write durable artifacts to disk before each advisor call. Run both for high-stakes systems and reconcile the outputs in `CROSS_PANEL_REPORT.md`.

### Advisor-pattern pipeline (Round 4/5, recommended)

Stages are dispatched via `panel/run_stage.sh`, which wraps `claude -p` with three structural guarantees:

1. **`--append-system-prompt-file panel/system-prompts/<stage>.md`** — keeps Claude Code's default system prompt (so Sonnet retains real tool-use grounding) and appends stage-specific role instructions. We discovered during a live panel run that specialized `subagent_type:` dispatch fully replaces the default system prompt, and the specialized agents lose tool-use grounding as a result, hallucinating `<tool_call>` XML instead of invoking tools. The advisor pattern sidesteps this entirely.
2. **`--output-format json --json-schema panel/schemas/<stage>.schema.json`** — every stage's output is validated against a JSON schema at the CLI boundary. Schema-violating output causes the stage to fail and the orchestrator to halt. This is the action-schema pattern from GitHub Engineering's *[Multi-agent workflows often fail](https://github.blog/ai-and-ml/generative-ai/multi-agent-workflows-often-fail-heres-how-to-engineer-ones-that-dont/)* analysis.
3. **`--allowedTools`** — explicit per-stage tool grant (least privilege at the CLI level).

Layout:

```
panel/
├── run_stage.sh                 # The dispatcher
├── render_markdown.sh           # JSON → markdown renderer
├── schemas/
│   ├── attack-scenarios.schema.json
│   ├── requirements.schema.json
│   ├── risk-analysis.schema.json
│   └── solutions.schema.json
└── system-prompts/
    ├── attack-scenarios.md
    ├── requirements.md
    ├── risk-analysis.md
    └── solutions.md
```

The legacy `subagent_type:` Agent-tool dispatch path is retained for one-off agent invocations (e.g. `Agent(subagent_type: "security-agent", ...)` for a single module audit) but is not recommended for multi-stage panels.

## Available Agents

| Agent | Executor | Advisor | Purpose |
|-------|----------|---------|---------|
| `security-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Static vulnerability analysis |
| `tron-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Live intrusion detection (runtime defender) |
| `ares-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Outside-in adversary emulation (Mythos-class) |
| `clu-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Alignment & scope watchdog (intent-level ASI02 monitoring) |
| `requirements-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Generate requirements from threats |
| `risk-analysis-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Risk analysis + red team tests |
| `solutions-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Design mitigations |
| `security-panel` | `claude-opus-4-7` | `claude-opus-4-6` | Defensive 3-stage pipeline (requirements → risk → solutions) |
| `red-team-panel` | `claude-opus-4-7` | `claude-opus-4-6` | Offensive 3-stage pipeline (ares → risk → solutions) |
| `system-health-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | Monitor system health |
| `maintenance-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | System maintenance |

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
Only Claude model IDs documented in `MODELS_ALLOWLIST.md` may be used. Because Claude models are served by Anthropic's API, identity is established by **exact-ID pinning + TLS** rather than a local weight digest.

To verify a model ID is allowlisted:
```bash
./verify-model-digest.sh claude-opus-4-7
```

### 3. Agent Integrity Verification
Each agent has an `integrity-hash-sha256` field (SHA-256 of the frontmatter block excluding the hash line itself). Run verification:
```bash
./verify-all-agents.sh
```

### 4. Kill Switch
If agents are compromised, refer to `SECURITY_INCIDENT_RUNBOOK.md` for the full termination procedure.

**Emergency termination (single command):**
```bash
pkill -9 -f "claude" && echo "All Claude agent processes killed"
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
./verify-all-agents.sh          # Verify all agent frontmatter hashes
./verify-model-digest.sh        # Verify a Claude model ID is allowlisted
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

- `model:` must match `executor:` — this is the field Claude Code subagents schema uses
- `tools:` is a comma-separated string (not a YAML list)
- `disallowedTools:`, `isolation:`, `color:`, `maxTurns:` are optional
- Compute `integrity-hash-sha256:` with `./verify-all-agents.sh` canonical command

## Approved Models

All models are Anthropic-served; they are referenced by exact model ID (no floating aliases). See `MODELS_ALLOWLIST.md` for full metadata.

- `claude-opus-4-7` — Flagship; deepest reasoning; 1M-token context. Advisor for security-critical agents; executor for security-panel.
- `claude-opus-4-6` — Strong reasoning; advisor for security-panel.
- `claude-sonnet-4-6` — Balanced executor/advisor; default for most agents.
- `claude-haiku-4-5` — Fast/cheap executor; used by system-health-agent and maintenance-agent.

## Key Files

| File / Directory | Purpose |
|------------------|---------|
| `WORKFLOW.md` | Operator how-to: panel runs, scheduling, parallel fan-out, worktrees |
| `ADVISOR_OUTPUT_CONTRACT.md` | Full contract for advisor output validation |
| `MODELS_ALLOWLIST.md` | Claude model IDs permitted in this repo |
| `SECURITY_INCIDENT_RUNBOOK.md` | Kill switch and incident response procedures |
| `COMMAND_SAFETY_GUIDELINES.md` | Safety guidelines for command execution |
| `SKILL_VERSION_POLICY.md` | Skill version pinning policy |
| `.claude/agents/` | Agent definitions with frontmatter (subagent dispatch path) |
| `panel/run_stage.sh` | Advisor-pattern stage dispatcher (recommended path) |
| `panel/schemas/` | JSON schemas — named edges between panel stages |
| `panel/system-prompts/` | Stage-specific appended system prompts |

## Running agents: Claude Code vs Copilot in VS Code

This system supports two execution surfaces. They share the agent definitions in `.claude/agents/` and produce the same artifacts; only the host runtime differs.

### Path A — Claude Code (recommended for full panels)

The orchestrator is the root Claude Code session (Opus 4.7). Dispatch the panel pipeline via `panel/run_stage.sh` (see Quick Start) or invoke individual agents via the Agent tool:

```bash
Agent(
  description: "Security audit of auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection, secret-leak, and authz bypass issues."
)
```

**Use when**: you want full multi-stage panels with structured-output validation, parallel Stage 2 fan-out, isolated worktrees for `solutions-agent`, and the long-context Opus 4.7 reasoning at orchestration decision points.

### Path B — Copilot in VS Code (recommended for inline iteration)

Each `.claude/agents/*.md` file is also a valid VS Code Copilot subagent. Use the `@` mention picker (`@<agent-name>`) or open the agents pane (`Ctrl+Shift+P` → *Agents: Show*). VS Code respects the same frontmatter (`model`, `tools`, `disallowedTools`, `isolation`, etc.).

**Use when**: you want inline review against the editor selection, you're working in a project that already uses Copilot for completion, or you need the agent to interact with the running editor (open files, terminal, problems pane).

**Caveat**: VS Code Copilot's agent runtime is not byte-identical to Claude Code; if you observe a divergence, the canonical execution path is Claude Code. The schema-validated `panel/run_stage.sh` pipeline runs through Claude Code only.

### Which to pick

- Multi-stage panel against a real codebase → Claude Code (Path A)
- Inline single-agent review while editing → Copilot in VS Code (Path B)
- Either path for one-off `security-agent` audits, `tron-agent` checks, or `system-health-agent` diagnostics

## References

### References for Claude Code (Anthropic-served models)

- Claude Code — *Subagents (frontmatter contract, isolation, hooks, memory)*: https://code.claude.com/docs/en/sub-agents
- Claude Code — *Common workflows (Plan Mode, worktrees, sessions, scheduling, hooks)*: https://code.claude.com/docs/en/common-workflows
- Claude Code — *Headless mode / Agent SDK CLI (`claude -p`, `--append-system-prompt-file`, `--output-format json --json-schema`, `--allowedTools`)*: https://code.claude.com/docs/en/headless
- Anthropic Engineering — *How we built our multi-agent research system (orchestrator-worker pattern, parallel subagents, artifact systems, durable resumption, end-state evaluation)*: https://www.anthropic.com/engineering/multi-agent-research-system
- GitHub Engineering — *Multi-agent workflows often fail. Here's how to engineer ones that don't (action-schema pattern, named concurrence, boundary validation — motivates `panel/schemas/` here)*: https://github.blog/ai-and-ml/generative-ai/multi-agent-workflows-often-fail-heres-how-to-engineer-ones-that-dont/
- AWS — *Multi-Agent collaboration patterns with Strands Agents (Agent Graphs framing for named edges between agents — motivates the explicit stage handoff schemas in `panel/schemas/`)*: https://aws.amazon.com/blogs/machine-learning/multi-agent-collaboration-patterns-with-strands-agents-and-amazon-nova/
- Anthropic Platform — *Advisor tool pattern (the executor + advisor split this repo implements)*: https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool

### References for Copilot in VS Code (Mainly Anthropic/Claude Models)

- VS Code Blog — *Multi-Agent Development in VS Code (run Claude agents alongside Copilot)*: https://code.visualstudio.com/blogs/2026/02/05/multi-agent-development
- GitHub Docs — *Anthropic Claude coding agent in Copilot*: https://docs.github.com/en/copilot/concepts/agents/anthropic-claude
- VS Code Docs — *Subagents in Visual Studio Code (context-isolated delegation for complex tasks)*: https://code.visualstudio.com/docs/copilot/agents/subagents
- VS Code Docs — *Using agents in Visual Studio Code (overview of local, cloud, Copilot CLI, handoffs, and orchestration)*: https://code.visualstudio.com/docs/copilot/agents/overview
- GitHub Docs — *Supported AI models in GitHub Copilot (includes multiple Claude variants)*: https://docs.github.com/copilot/reference/ai-models/supported-models
- GitHub Blog — *Pick your agent: Use Claude and Codex on Agent HQ (multi-agent in VS Code/GitHub)*: https://github.blog/news-insights/company-news/pick-your-agent-use-claude-and-codex-on-agent-hq/
- Community/GitHub Discussions — *Best practices for orchestrating multiple agents/skills in Copilot Chat (custom .agent.md, coordinator-subagent patterns, AGENTS.md, MEMORY.md)*: https://github.com/orgs/community/discussions/192232
