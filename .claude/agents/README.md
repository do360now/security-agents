# Claude Code Agents — Ollama Advisor Pattern

Custom agents that pair a **fast executor** with a **stronger advisor** — both running on open-weight models via Ollama. Loosely modelled on Anthropic's [advisor tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool).

## Why the advisor pattern

Most work on agentic tasks is mechanical (listing files, running commands, reading output). The hard part is picking the *right plan*. The advisor pattern keeps token-heavy execution on a cheap model and reserves the expensive model for the handful of decision points that matter.

## Agents

| Agent | Executor | Advisor | Description |
|-------|----------|---------|-------------|
| `security-agent` | `devstral-small-2:cloud` | `glm-5.1:cloud` | Vulnerability scan, code review |
| `system-health-agent` | `ministral-3:cloud` | `gemma4:cloud` | Process/resource diagnostics |
| `maintenance-agent` | `minimax-m2.5:cloud` | `devstral-2:cloud` | Updates, cleanup, optimization |

All models run on Ollama **cloud** (`:cloud` suffix) — no local GPU. Claude Code itself is launched with e.g. `ollama launch claude --model minimax-m2.5:cloud`; the agent then shells out to other cloud models for advisor consultations. Swap in any cloud models you prefer — pairing (fast ↔ strong) matters more than names.

## Usage

```
Agent(
  description: "Audit auth module",
  subagent_type: "security-agent",
  prompt: "Scan src/auth/ for injection and authz issues."
)
```

## Advisor invocation

The executor shells out to Ollama at three moments: early (after orientation), when stuck, and before declaring done.

```bash
ollama run glm-5.1:cloud "$(cat <<'EOF'
You are a security advisor. Respond in under 100 words, enumerated steps only.

<task>Audit src/auth/ for injection/authz issues</task>
<findings>
- login.py uses raw string concat in 3 queries
- session token stored in localStorage
- /admin/* routes check cookie presence, not signature
</findings>

Where should the executor look next, and what should it prioritize?
EOF
)"
```

## Adding agents

See `CLAUDE.md` in this directory for the frontmatter contract and body guidelines.
