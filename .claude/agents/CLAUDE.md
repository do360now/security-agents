# CLAUDE.md — Agents Directory

These agents implement the **advisor pattern** using open-weight Ollama models: a fast executor handles most of the work, and a stronger advisor is consulted at strategic moments for plans and course corrections.

## The advisor pattern

Inspired by Anthropic's advisor tool (https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool): pair a faster executor with a higher-intelligence advisor that reads the full context and produces concise guidance (target: under 100 words, enumerated steps).

**When the executor calls the advisor:**
1. Early — after orientation (file reads, listing commands) but *before* substantive work.
2. When stuck — recurring errors, approach not converging.
3. Before declaring done — after writes and test output are in transcript. Make the deliverable durable first (file written, change saved) so a timeout mid-advice doesn't lose work.

**How the executor treats advice:** follow it unless empirical evidence contradicts a specific claim. A passing self-test is not evidence the advice is wrong. If your evidence conflicts with advice, do one reconcile call rather than silently switching.

## How to invoke the advisor

Shell out via Bash:

```bash
ollama run <advisor-model>:cloud "$(cat <<'EOF'
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

For long transcripts, pipe via stdin: `ollama run <model>:cloud < prompt.txt`.

## Agents

| Agent | Executor | Advisor | Use |
|-------|----------|---------|-----|
| `security-agent` | `devstral-small-2:24b-cloud` | `glm-5.1:cloud` | Vulnerability scanning, code review |
| `system-health-agent` | `ministral-3:14b-cloud` | `gemma4:31b-cloud` | Process/resource diagnostics |
| `maintenance-agent` | `minimax-m2.5:cloud` | `devstral-2:123b-cloud` | Updates, cleanup, optimization |
| `requirements-agent` | `devstral-2:123b-cloud` | `devstral-2:123b-cloud` | Generate security requirements from threat intel |
| `risk-analysis-agent` | `glm-5.1:cloud` | `glm-5.1:cloud` | Red-team test generation and risk scoring |
| `solutions-agent` | `devstral-small-2:24b-cloud` | `devstral-small-2:24b-cloud` | Defensive solution design and mitigation |
| `security-panel` | `devstral-2:123b-cloud` | `devstral-2:123b-cloud` | Orchestrates full 3-stage AI security pipeline |

All models are Ollama **cloud** models (the `:cloud` suffix) — no local GPU required, inference runs on Ollama's servers. Claude Code itself is launched against one of these via `ollama launch claude --model <name>:cloud`. The executor/advisor split applies inside each agent's workflow: the executor drives the loop, the advisor is consulted via `ollama run <advisor>:cloud` at decision points.

Substitute any cloud models you prefer — the pairing (small/fast executor, stronger advisor) matters more than exact names.

## Invocation

```
Agent(
  description: "Security audit of auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection, secret-leak, and authz bypass issues. The login flow was recently refactored — focus there."
)
```

## Adding new agents

Frontmatter contract:

```yaml
---
name: my-agent
description: One-line purpose (shown in agent picker)
executor: ollama-small-model:cloud
advisor: ollama-large-model:cloud
tools:
  - name: Bash
  - name: Read
  - name: Grep
skills: []
---
```

Body should specify: responsibilities, advisor-call timing for *this* agent's workflow, and concrete example `ollama run` prompts tailored to the domain.

## Permissions

Agents require tool permissions configured in `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "WebFetch(domain:ollama.com)",
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

- `Bash` — for running system commands and invoking advisor via `ollama run`
- `Read/Write/Edit/Glob/Grep` — for file operations
- `WebFetch(domain:ollama.com)` — for advisor model calls
