# Explanation — The Advisor Pattern

Why this system pairs a fast executor with a stronger advisor.

## The Problem with One Model

A single model handling everything is a trade-off:
- Use a strong model for everything → expensive, slow
- Use a fast model for everything → misses edge cases, worse reasoning

## The Solution: Split Roles

The advisor pattern splits work between two models:

| Role | Model | Responsibility |
|------|-------|----------------|
| **Executor** | Fast, small (e.g., devstral-small-2:24b) | Drive the loop — reads files, runs commands, writes output |
| **Advisor** | Strong, large (e.g., devstral-2:123b) | Strategic guidance at decision points |

The executor handles the token-heavy work (file reads, command output) at low cost. The advisor is consulted briefly at moments that benefit from stronger reasoning.

## When to Call the Advisor

The executor calls the advisor at three moments:

### 1. After Initial Recon
After reading relevant files and running diagnostic commands, but before committing to a plan. The executor has context but hasn't acted yet.

**Why:** Prevents going down the wrong path based on incomplete information.

### 2. When Stuck
After retries fail, errors recur, or the approach isn't converging. The executor has evidence the current path isn't working.

**Why:** A fresh perspective can identify what's being missed.

### 3. Before Declaring Done
After the main work is complete and output is written to disk. The executor gets a final review before finishing.

**Why:** Catches gaps the executor missed and validates the deliverable.

## How It Works

The executor shells out to the advisor via `ollama run`:

```bash
ollama run <advisor>:cloud "$(cat <<'EOF'
You are a <domain> advisor. Respond in under 100 words, enumerated steps only.

<task>[what the executor is trying to accomplish]</task>
<transcript>[what the executor has found so far]</transcript>
What should the executor do next?
EOF
)"
```

Key detail: `cat <<'EOF'` — the single quotes around EOF prevent variable expansion. The advisor sees only the structured tags, not any secrets or context from the outer shell.

## Why Not Just Use One Strong Model?

1. **Cost** — devstral-small-2 costs far fewer tokens per task than devstral-2
2. **Speed** — fast models respond in seconds vs. minutes for large models
3. **Separation of concerns** — the executor does work, the advisor reviews strategy
4. **Chain-of-thought discipline** — the executor must articulate findings before getting advice

## Security Properties

The advisor pattern provides security benefits:

- **Context poisoning defense** — the advisor reads structured `<task>` and `<transcript>` tags, not raw transcript. External file content that an agent was tricked into reading doesn't automatically reach the advisor.
- **Output validation** — advisor responses are validated against a contract (no bash commands, no URLs, no shell metacharacters)
- **Model diversity** — executors and advisors are different models. Compromising the executor doesn't automatically compromise the advisor, and vice versa.

## See Also

- [Reference: Agent Roster](../reference/agent-roster.md) — All agents and their model pairings
- [Command Safety Guidelines](../COMMAND_SAFETY_GUIDELINES.md) — Safe advisor construction
- [Advisor Output Contract](../ADVISOR_OUTPUT_CONTRACT.md) — Valid advisor responses
