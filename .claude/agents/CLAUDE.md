# CLAUDE.md — Agents Directory

**Context: The Mythos Era (April 2026)**

Claude Mythos Preview represents a watershed moment for security. Frontier AI models can now autonomously find and exploit zero-day vulnerabilities at scale:
- 181 working Firefox exploits in internal benchmarks
- Full control flow hijack on 10 fully-patched targets
- 99%+ of findings were unpatched vulnerabilities
- Autonomous exploit development without human intervention

These agents are designed to help defenders respond to AI-capable adversaries.

---

These agents implement the **advisor pattern** using the Claude model family: a fast executor handles most of the work, and a stronger advisor is consulted at strategic moments for plans and course corrections.

## The advisor pattern

Inspired by Anthropic's advisor tool (https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool): pair a faster executor with a higher-intelligence advisor that reads the full context and produces concise guidance (target: under 100 words, enumerated steps).

**When the executor calls the advisor:**
1. Early — after orientation (file reads, listing commands) but *before* substantive work.
2. When stuck — recurring errors, approach not converging.
3. Before declaring done — after writes and test output are in transcript. Make the deliverable durable first (file written, change saved) so a timeout mid-advice doesn't lose work.

**How the executor treats advice:** follow it unless empirical evidence contradicts a specific claim. A passing self-test is not evidence the advice is wrong. If your evidence conflicts with advice, do one reconcile call rather than silently switching.

## How to invoke the advisor

Shell out via Bash, using the Claude Code CLI in non-interactive print mode:

```bash
claude -p --model <advisor-model> "$(cat <<'EOF'
You are a security/sysadmin/etc. advisor. The executor has context below.
Respond in under 100 words using enumerated steps, not explanations.

<task>
[current task]
</task>

<transcript>
[what the executor has found so far — file paths, errors, partial output]
</transcript>

What should the executor do next?
EOF
)"
```

For long transcripts, pipe via stdin: `claude -p --model <advisor-model> < prompt.txt`.

Alternatively, advisor calls can be made via the Anthropic SDK (Python/Node) against the Claude API — use the same model IDs.

## Claude model family

| Model | ID | Role |
|-------|----|----|
| Opus 4.7 | `claude-opus-4-7` | Flagship — deepest reasoning, long-context (1M tokens) |
| Opus 4.6 | `claude-opus-4-6` | Strong reasoning |
| Sonnet 4.6 | `claude-sonnet-4-6` | Balanced — default for executors |
| Haiku 4.5 | `claude-haiku-4-5` | Fast/cheap — lightweight executors |

## Agents

| Agent | Executor | Advisor | Color | Use |
|-------|----------|---------|-------|-----|
| `security-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | blue | Static vulnerability scanning, code review |
| `tron-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | cyan | Live intrusion detection (runtime defender) |
| `ares-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | red | Outside-in adversary emulation (Mythos-class) |
| `clu-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | yellow | Alignment & scope watchdog (intent-level ASI02 monitoring) |
| `system-health-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | cyan | Process/resource diagnostics |
| `maintenance-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | orange | Updates, cleanup, optimization |
| `requirements-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | purple | Generate security requirements from threat intel |
| `risk-analysis-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | orange | Red-team test generation and risk scoring |
| `solutions-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | green | Defensive solution design and mitigation |
| `security-panel` | `claude-opus-4-7` | `claude-opus-4-6` | pink | Orchestrates defensive 3-stage pipeline (requirements → risk → solutions) |
| `red-team-panel` | `claude-opus-4-7` | `claude-opus-4-6` | red | Orchestrates offensive 3-stage pipeline (ares → risk → solutions) |

**Rationale**: security-critical stages (scan, requirements, risk, solutions) pair Sonnet 4.6 execution with Opus 4.7 advisory review — the strongest available reasoning at decision points. Routine diagnostic/maintenance agents use Haiku 4.5 + Sonnet 4.6 to keep operating cost low while still having strong reasoning on tap. The orchestrator itself runs Opus 4.7 because picking stage order and reconciling stage outputs benefits from the flagship model.

## Invocation

These agents run on TWO surfaces. The frontmatter and body are identical; only the host differs.

### Claude Code (canonical)

For one-off agent dispatch:

```
Agent(
  description: "Security audit of auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection, secret-leak, and authz bypass issues. The login flow was recently refactored — focus there."
)
```

For multi-stage panel runs, use the advisor-pattern dispatcher at `panel/run_stage.sh` (repo root) — it wraps `claude -p` with `--append-system-prompt-file`, `--output-format json --json-schema`, and `--allowedTools`. This is the recommended path; specialized `subagent_type:` dispatch lost tool-use grounding in our smoke tests because the agent body fully replaces Claude Code's default system prompt. See repo root `README.md` § "Advisor-pattern pipeline" for the architecture and `WORKFLOW.md` for runbooks.

### Copilot in VS Code

`@<agent-name>` in the chat picker, or open the agents pane (`Ctrl+Shift+P` → *Agents: Show*). Same frontmatter contract — `model`, `tools`, `disallowedTools`, `isolation`, etc. all honored. VS Code does not run the `panel/run_stage.sh` schema pipeline; for that, use Claude Code.

## Adding new agents

Frontmatter contract:

```yaml
---
name: my-agent
description: One-line purpose (shown in agent picker)
executor: claude-sonnet-4-6
advisor: claude-opus-4-7
model: claude-sonnet-4-6
integrity-hash-sha256: SHA256:<hash>
tools: Bash, Read, Grep
disallowedTools: Edit, Write
isolation: worktree
color: blue
maxTurns: 60
skills: []
---
```

Required fields: `name`, `description`, `executor`, `advisor`, `model`, `integrity-hash-sha256`, `tools`, `skills`.
Optional fields: `disallowedTools`, `isolation`, `color`, `maxTurns`.

- `model`: must match `executor` — sets the model Claude Code uses for this agent
- `tools`: comma-separated string of permitted tool names (e.g., `Read, Grep, Bash`). Panel orchestrators may include `Agent(agent-name, ...)` entries to declare subagent invocation permissions.
- `disallowedTools`: comma-separated string of tools the agent must not use, even if available in the session
- `isolation`: `worktree` causes Claude Code to run the agent in a git worktree; use for agents that write files (e.g., `ares-agent`, `solutions-agent`)
- `color`: terminal color for the agent's output (blue, cyan, red, yellow, green, orange, purple, pink, etc.)
- `maxTurns`: maximum turn count before the agent halts; tune by agent role (CLU: 20, health agents: 30, analysis agents: 60, solutions: 80, panels: 100)

**Subagents cannot spawn other subagents.** Panel orchestrators (`security-panel`, `red-team-panel`) must run as the main session via `claude --agent <panel>` to use parallel fan-out. When invoked via the Agent tool from another session, panels fall back to sequential stage execution.

`executor` and `advisor` fields are repo-specific documentation — they are referenced in advisor-call examples in the agent body. `model:` is the Claude Code subagents schema field that actually controls which model runs.

Body should specify: responsibilities, advisor-call timing for *this* agent's workflow, and concrete example `claude -p` prompts tailored to the domain.

`WORKFLOW.md` (repo root) is the operator-facing how-to for panel runs, scheduling, and parallel fan-out.

## Tool response sizing

Tool outputs consume the agent's context window. Per Anthropic's *Writing effective tools for agents*:

- **Cap large reads**: tools returning code, logs, or scan output should default to ~25K tokens (Claude Code's built-in `Read` cap). For larger files, use offset/limit parameters rather than returning the whole file in one call.
- **Prefer high-leverage tools**: a single `get_threat_context(target)` returning a compiled summary beats three separate calls to `list_cves`, `list_known_exploits`, `list_iocs`.
- **Pre-compute summaries**: don't make the agent aggregate statistics it could read pre-aggregated. The C-compiler experiment (*Building a C compiler with a team of parallel Claudes*) found agents waste hours running full test suites when a sampled summary would be sufficient.
- **Sub-agent returns**: when a subagent finishes, its reply to the orchestrator should be 1,000–2,000 tokens (or less); the full artifact lives on disk in `/tmp/ai-security-panel/`. The `clu-agent` and `evaluator-agent` enforce ≤50-word returns as the tightest case.

This project uses Claude Code's built-in `Read`/`Grep`/`Glob`, which respect the 25K cap automatically. When adding a custom tool via an agent's `tools:` frontmatter, follow the same defaults — and add an enum parameter (e.g., `format: "concise"|"detailed"`) for tools whose callers don't always need the full output.

## Permissions

Agents require tool permissions configured in `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:anthropic.com)",
      "WebFetch(domain:docs.claude.com)",
      "Bash",
      "Read",
      "Write",
      "Edit",
      "Grep",
      "Glob"
    ]
  }
}
```

- `Bash` — for running system commands and invoking advisor via `claude -p --model ...`
- `Read/Write/Edit/Glob/Grep` — for file operations
- `WebFetch(domain:anthropic.com|docs.claude.com)` — for documentation lookups

Note: advisor invocation via the `claude` CLI uses your existing Anthropic authentication — no separate WebFetch permission is needed for the API call itself.
