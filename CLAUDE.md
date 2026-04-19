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
.claude/agents/     Agent definitions
```

Full project documentation is in `README.md`.

## Agent Frontmatter Contract

All agents in `.claude/agents/` must have this frontmatter:

```yaml
---
name: <name>
description: One-line purpose
integrity-hash-sha256: SHA256:<hash>
executor: <model>:cloud
advisor: <different-model>:cloud
tools:
  - name: Bash
  - name: Read
skills: []
---
```

**Rules:**
- Executor and advisor must be different models
- Compute the hash: `./verify-all-agents.sh`
- Skills must be version-pinned (no `latest`)

## Advisor Pattern

Call the advisor at three moments:
1. After initial recon (before committing to a plan)
2. When stuck (approach not converging)
3. Before declaring done (output on disk first)

Use `cat <<'EOF'` for advisor calls — never `cat <<EOF` (variable expansion leaks).

Validate advisor output: `./validate-advisor-output.sh`

## Security Controls

- Run `./verify-all-agents.sh` after modifying any agent
- Bash is domain-restricted to localhost in `.claude/settings.local.json`
- Advisor output is validated against `ADVISOR_OUTPUT_CONTRACT.md`
- Config drift is monitored: `./detect-config-drift.sh` on session start
- No floating skill versions — use exact versions or commit hashes

## Key Commands

```bash
./setup-and-redteam.sh          # Run all 22 tests
./verify-all-agents.sh          # Verify agent hashes
./detect-config-drift.sh        # Check for config tampering
./validate-advisor-output.sh    # Validate advisor response
```

## Adding New Agents

1. Create `.claude/agents/<name>-agent.md` with frontmatter
2. Compute hash: `./verify-all-agents.sh`
3. Update the `integrity-hash-sha256` field with the computed hash
4. Verify: `./verify-all-agents.sh` passes

## Permissions

Configured in `.claude/settings.local.json`. Changes trigger drift alerts.

## See Also

- `README.md` — Full project overview
- `tutorial/getting-started.md` — Step-by-step introduction
- `how-to/add-new-agent.md` — Detailed agent creation guide
- `explanation/advisor-pattern.md` — Why the advisor pattern works
