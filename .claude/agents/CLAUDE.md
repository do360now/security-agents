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

| Agent | Executor | Advisor | Use |
|-------|----------|---------|-----|
| `security-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Vulnerability scanning, code review |
| `system-health-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | Process/resource diagnostics |
| `maintenance-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | Updates, cleanup, optimization |
| `requirements-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Generate security requirements from threat intel |
| `risk-analysis-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Red-team test generation and risk scoring |
| `solutions-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Defensive solution design and mitigation |
| `security-panel` | `claude-opus-4-7` | `claude-opus-4-6` | Orchestrates full 3-stage AI security pipeline |

**Rationale**: security-critical stages (scan, requirements, risk, solutions) pair Sonnet 4.6 execution with Opus 4.7 advisory review — the strongest available reasoning at decision points. Routine diagnostic/maintenance agents use Haiku 4.5 + Sonnet 4.6 to keep operating cost low while still having strong reasoning on tap. The orchestrator itself runs Opus 4.7 because picking stage order and reconciling stage outputs benefits from the flagship model.

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
executor: claude-sonnet-4-6
advisor: claude-opus-4-7
integrity-hash-sha256: SHA256:<hash>
tools:
  - name: Bash
  - name: Read
  - name: Grep
skills: []
---
```

Body should specify: responsibilities, advisor-call timing for *this* agent's workflow, and concrete example `claude -p` prompts tailored to the domain.

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
