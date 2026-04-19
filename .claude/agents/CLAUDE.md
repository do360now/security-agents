# CLAUDE.md — Agents Directory

**Context: The Mythos Era (April 2026)**

Claude Mythos Preview represents a watershed moment for security. Frontier AI models can now autonomously find and exploit zero-day vulnerabilities at scale:
- 181 working Firefox exploits in internal benchmarks
- Full control flow hijack on 10 fully-patched targets
- 99%+ of findings were unpatched vulnerabilities
- Autonomous exploit development without human intervention

These agents are designed to help defenders respond to AI-capable adversaries.

---

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

| Agent | Executor (local) | Advisor (cloud) | Use |
|-------|------------------|-----------------|-----|
| `security-agent` | `qwen2.5:3b` | `devstral-small-2:24b-cloud` | Vulnerability scanning, code review |
| `system-health-agent` | `qwen2.5:3b` | `gemma4:31b-cloud` | Process/resource diagnostics |
| `maintenance-agent` | `qwen2.5:3b` | `devstral-2:123b-cloud` | Updates, cleanup, optimization |
| `requirements-agent` | `qwen2.5:7b` | `devstral-2:123b-cloud` | Generate security requirements from threat intel |
| `risk-analysis-agent` | `qwen2.5:7b` | `glm-5.1:cloud` | Red-team test generation and risk scoring |
| `solutions-agent` | `qwen2.5:3b` | `devstral-small-2:24b-cloud` | Defensive solution design and mitigation |
| `security-panel` | `qwen2.5:7b` | `devstral-2:123b-cloud` | Orchestrates full 3-stage AI security pipeline |

**Mixed setup**: Local models (GTX 1070 compatible) handle the execution loop, cloud models provide strong reasoning at decision points. The executor runs frequently (iteration, file ops, command execution), the advisor is called sparingly (planning, validation, complex reasoning).

Claude Code can be launched with either local or cloud models via `ollama launch claude --model <name>`. The executor drives the loop, the advisor is consulted via `ollama run <advisor>:cloud` at decision points.

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
