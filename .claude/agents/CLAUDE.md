# CLAUDE.md — Agents Directory

These agents implement the **orchestrator-worker pattern** described in Anthropic's [multi-agent research system writeup](https://www.anthropic.com/engineering/multi-agent-research-system) and the [evaluator-optimizer pattern](https://www.anthropic.com/engineering/building-effective-agents) from "Building Effective Agents". A planning-class model (**Opus 4.7**) decomposes the task and reviews work; an implementation-class model (**Sonnet 4.6**, or **Haiku 4.5** for lightweight diagnostics) does the mechanical execution.

**Anthropic-only.** All agents call models via the Claude API or the `claude` CLI in headless mode (`claude -p --model …`). No Ollama, no third-party providers.

## Why this split (and which model where)

Anthropic's internal evaluations show a multi-agent system with **Claude Opus 4 as lead and Claude Sonnet 4 as workers** outperformed a single-agent Opus 4 by ~90.2% on research-style tasks. Token usage explained 80% of the variance — paying for many cheap-but-capable Sonnet calls beats one expensive Opus call. We adopt the same shape:

- **Opus 4.7 (`claude-opus-4-7`)** — plans, decomposes, critiques. Used as the **advisor** everywhere, and as the **executor** for the lead orchestrator (`security-panel`) and the requirements stage.
- **Sonnet 4.6 (`claude-sonnet-4-6`)** — implements. Default executor for security review, risk analysis, solutions design, and maintenance.
- **Haiku 4.5 (`claude-haiku-4-5`)** — fastest with near-frontier intelligence. Executor for lightweight diagnostics (`system-health-agent`).

Model IDs and aliases come from <https://platform.claude.com/docs/en/about-claude/models/overview>. Use the alias (`claude-opus-4-7`) for routine work; pin to a snapshot ID when reproducibility matters.

## The advisor pattern (= evaluator-optimizer)

The executor calls the advisor at three moments. This is the [evaluator-optimizer](https://www.anthropic.com/engineering/building-effective-agents) loop: one model produces, another evaluates and steers.

1. **Early** — after orientation (file reads, listing commands) but *before* substantive work. Ask the advisor for a plan, not for code.
2. **When stuck** — recurring errors, an approach not converging, conflicting evidence.
3. **Before declaring done** — after writes and test output are durable on disk. Make the deliverable persistent first so a timeout mid-advice never loses work.

**How the executor treats advice:** follow it unless empirical evidence contradicts a specific claim. A passing self-test is not evidence the advice is wrong. If your evidence conflicts with advice, do one reconcile call rather than silently switching strategies.

This mirrors Anthropic's guidance: use evaluator-optimizer when "clear evaluation criteria exist and iterative refinement provides measurable value" — security findings, requirement quality, and remediation correctness all qualify.

## Software-design grounding (Ousterhout, AI era)

All review work — agent code, audit output, mitigation patches — is graded against **A Philosophy of Software Design, 2nd ed.** John Ousterhout's [April 2025 commentary](https://newsletter.pragmaticengineer.com/p/the-philosophy-of-software-design) reinforces this in the AI era:

- AI tools are "tactical tornadoes" — fast at low-level code, prolific at producing technical debt. Design-level thinking matters *more*, not less.
- **Software design is decomposition.** Breaking systems into independently implementable units is the central activity.
- **Deep modules**: simple interfaces over substantial functionality. Reject Clean-Code-style fragmentation when it widens interfaces.
- **Strategic over tactical**: invest design effort up front; do not let LLM speed seduce you into accepting tactical debt.
- **Comments still matter**, even (especially) when LLMs read code well — comments capture *intent* the code cannot.

When an advisor or executor disagrees with one of these principles, surface the conflict; do not paper over it.

## How to invoke the advisor

Shell out via Bash to the headless `claude` CLI. The `cat <<'EOF'` form (single-quoted heredoc) prevents shell expansion of any `$VAR` in the prompt body — required to keep advisor inputs literal.

```bash
claude -p --model claude-opus-4-7 "$(cat <<'EOF'
You are a security/sysadmin/etc. advisor. Respond in under 100 words using
enumerated steps, not explanations.

<task>
[current task]
</task>

<transcript>
[what the executor has found so far — file paths, errors, partial output;
 escape any literal '<' and '>' in user-supplied content]
</transcript>

What should the executor do next?
EOF
)"
```

For long transcripts, pipe via stdin:

```bash
claude -p --model claude-opus-4-7 < /tmp/advisor-prompt.txt
```

Always pass `--model` explicitly — never inherit the parent session's model for an advisor call, or the "advice" is just self-talk.

## Agents

| Agent | Executor | Advisor | Use |
|-------|----------|---------|-----|
| `security-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Vulnerability scanning, code review |
| `system-health-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` | Process/resource diagnostics |
| `maintenance-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Updates, cleanup, optimization |
| `requirements-agent` | `claude-opus-4-7` | `claude-opus-4-7` | Generate security requirements from threat intel (planning IS the work) |
| `risk-analysis-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Red-team test generation and risk scoring |
| `solutions-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` | Defensive solution design and mitigation |
| `security-panel` | `claude-opus-4-7` | `claude-opus-4-7` | Lead orchestrator for the 3-stage panel |

Two agents (`requirements-agent`, `security-panel`) intentionally use Opus on both sides because their job *is* planning — there is no cheaper-and-still-capable model below Opus that fits. The advisor call there functions as a self-critique pass with a fresh context window.

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

    name: my-agent
    description: One-line purpose (shown in agent picker)
    executor: claude-sonnet-4-6
    advisor: claude-opus-4-7
    tools:
      - name: Bash
      - name: Read
      - name: Grep
    skills: []

The frontmatter must be wrapped in `---` triple-dash markers and include an `integrity-hash-sha256:` field with the `SHA256:` prefix. Compute the hash with `./verify-all-agents.sh` (it prints the expected value on first run) and paste the result into the frontmatter, then re-run to confirm `PASS`.

Body should specify: responsibilities, advisor-call timing for *this* agent's workflow, and concrete example `claude -p --model …` prompts tailored to the domain.

## Permissions

Agents require tool permissions configured in `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(claude -p --model claude-opus-4-7:*)",
      "Bash(claude -p --model claude-sonnet-4-6:*)",
      "Bash(claude -p --model claude-haiku-4-5:*)",
      "Read",
      "Write",
      "Edit",
      "Grep",
      "Glob"
    ]
  }
}
```

- `Bash(claude -p --model …)` — for advisor calls via the headless CLI
- `Read/Write/Edit/Glob/Grep` — for file operations

`ANTHROPIC_API_KEY` (or an equivalent Bedrock/Vertex credential) must be set in the environment for headless `claude -p` to authenticate.
