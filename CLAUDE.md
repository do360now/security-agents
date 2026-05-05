# CLAUDE.md

Project-specific guidance for Claude Code agents working in this repository.

## System Overview

This is a defensive AI security team built with Claude Code + Ollama cloud models. It uses an advisor pattern (fast executor + strong advisor) with defense-in-depth controls. All 22 red-team tests pass.

## Project Structure

```
tutorial/           Learning-oriented guides
how-to/             Task-oriented guides
reference/          Technical reference
explanation/        Deep dives on design decisions
.claude/agents/     Agent definitions (7 agents, SHA256 integrity hashes)
.claude/skills/     Skill files (46 skills, framework-grounded, auto-discovered)
```

Full project documentation is in `README.md` and `ARCHITECTURE.md`.

## Agent Frontmatter Contract

All agents in `.claude/agents/` must have this frontmatter:

```yaml
---
name: <name>
description: One-line purpose
integrity-hash-sha256: SHA256:<hash>   # SHA256: prefix is required
executor: <model>:cloud
advisor: <different-model>:cloud
tools:
  - name: Bash
  - name: Read
skills:
  - name: <skill-name>
    version: "<version>"   # version-pinned, no 'latest'
---
```

**Rules:**
- Executor and advisor must be different models
- Compute the hash: `./verify-all-agents.sh`
- Skills must use exact versions or commit hashes, not `latest`

## Advisor Pattern

Call the advisor at three moments:
1. After initial recon (before committing to a plan)
2. When stuck (approach not converging)
3. Before declaring done (output on disk first)

Use `cat <<'EOF'` for advisor calls — the single quotes around EOF prevent variable expansion, so any `$VAR` in the prompt stays literal. Using unquoted `cat <<EOF` leaks shell variables into the prompt.

Validate advisor output: `./validate-advisor-output.sh`

## Security Controls

- Run `./verify-all-agents.sh` after modifying any agent
- Run `./verify-all-skills.sh` after modifying any skill file
- Bash is domain-restricted to localhost in `.claude/settings.local.json`
- Advisor output is validated against `ADVISOR_OUTPUT_CONTRACT.md`
- Config drift is monitored: `./detect-config-drift.sh` on session start
- No floating skill versions — use exact versions or commit hashes

## Key Commands

```bash
./setup-and-redteam.sh          # Run all 22 tests (also installs pre-commit hook)
make red-team-test              # Quick pass/fail summary
make red-team-full              # Verbose per-test output
./verify-all-agents.sh           # Verify agent hashes
./verify-all-skills.sh          # Verify skill file hashes
./feedback-loop.sh              # Route red-team failures to skills needing updates
./detect-config-drift.sh        # Check for config tampering
./validate-advisor-output.sh    # Validate advisor response contract
./verify-skill-versions.sh      # No floating skill versions
./verify-agent-hash.sh <file>   # Compute hash for an agent file
```

## Important Project Artifacts

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | System overview — how agents, skills, advisor pattern, and pipeline fit together |
| `SKILL_AUTO_INVOKE.md` | Context-to-skill mapping for auto-invocation |
| `SECURITY_INCIDENT_RUNBOOK.md` | Kill switch and incident response procedures |
| `AGENT_LOGGING_SCHEMA.md` | Audit logging schema (90-day retention, tool_invocation events) |
| `MODELS_ALLOWLIST.md` | Model provenance with SHA256 digests |

## Adding New Agents

1. Create `.claude/agents/<name>-agent.md` with frontmatter (see below)
2. Compute hash: `./verify-all-agents.sh`
3. Update the `integrity-hash-sha256` field with the computed hash (format: `SHA256:<hash>`)
4. Verify: `./verify-all-agents.sh` passes

## Adding New Skills

1. Copy skill file to `.claude/skills/<name>/SKILL.md`
2. Run `./add-skill-hashes.sh` to compute and add integrity hash
3. Verify: `./verify-all-skills.sh` passes
4. Update agent's skills array with version-pinned entry:
   ```yaml
   skills:
     - name: <skill-name>
       version: "<version>"
   ```

## Skill Auto-Invocation

When starting a review, detect the target type and load the relevant skill before analysis:

```bash
# Context detection → skill selection
TARGET_TYPE=$(file target/ | tr ',' '\n' | grep -iE "rest|web|llm|cloud|container" | head -1)
case "$TARGET_TYPE" in
  api|REST|GraphQL)  SKILL_NAME="api-security" ;;
  web|HTML|JS)       SKILL_NAME="owasp-top-10-web" ;;
  LLM|RAG|Prompt)    SKILL_NAME="prompt-injection" ;;
  cloud|Terraform)   SKILL_NAME="iac-security" ;;
  container|Docker)  SKILL_NAME="container-security" ;;
  *)                 SKILL_NAME="secure-code-review" ;;
esac
cat .claude/skills/$SKILL_NAME/SKILL.md
```

See `SKILL_AUTO_INVOKE.md` for the full context-to-skill map.

## Incident Response (Kill Switch)

```bash
# Emergency termination — run if agents behave anomalously
pkill -9 -f "ollama" && pkill -9 -f "claude" && echo "All agent processes killed"

# Verify isolation
ps aux | grep -E "ollama|claude" | grep -v grep || echo "Verified isolated"

# Snapshot evidence
tar -czf /tmp/agent-config-snapshot-$(date +%Y%m%d-%H%M%S).tar.gz .claude/
ps aux > /tmp/process-snapshot-$(date +%Y%m%d-%H%M%S).log
```

## Permissions

Configured in `.claude/settings.local.json`. Changes trigger drift alerts.

## See Also

- `README.md` — Full project overview
- `ARCHITECTURE.md` — How everything fits together
- `tutorial/getting-started.md` — Step-by-step introduction
- `how-to/add-new-agent.md` — Detailed agent creation guide
- `explanation/advisor-pattern.md` — Why the advisor pattern works
- `SKILL_AUTO_INVOKE.md` — Skill auto-invocation map
