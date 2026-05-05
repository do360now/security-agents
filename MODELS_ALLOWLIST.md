# Anthropic Model Allowlist

**Policy**: Only models listed here may be referenced in agent configurations or invoked via `claude -p --model …`. Unlike open-weight models distributed by digest, Anthropic models are accessed via the Claude API (or AWS Bedrock / GCP Vertex AI) — provenance is established by Anthropic's hosted snapshot date rather than a local file digest.

**Verification**: `claude --version` confirms the Claude CLI build; the API/Bedrock/Vertex platform binds the snapshot ID. Pin to the dated snapshot ID when reproducibility matters; use the alias for routine work.

Reference: <https://platform.claude.com/docs/en/about-claude/models/overview>

---

## Approved current-generation models

### claude-opus-4-7  (Opus 4.7)
- **API ID / alias**: `claude-opus-4-7`
- **AWS Bedrock ID**: `anthropic.claude-opus-4-7`
- **GCP Vertex AI ID**: `claude-opus-4-7`
- **Role**: Lead orchestrator and advisor (planner). Used as executor in `requirements-agent` and `security-panel`; used as advisor in every other agent.
- **Pricing**: $5 / input MTok, $25 / output MTok
- **Context**: 1M tokens · **Max output**: 128k tokens
- **Reliable knowledge cutoff**: Jan 2026
- **Adaptive thinking**: yes
- **Added**: 2026-05-05

### claude-sonnet-4-6  (Sonnet 4.6)
- **API ID / alias**: `claude-sonnet-4-6`
- **AWS Bedrock ID**: `anthropic.claude-sonnet-4-6`
- **GCP Vertex AI ID**: `claude-sonnet-4-6`
- **Role**: Default executor (implementer) for `security-agent`, `risk-analysis-agent`, `solutions-agent`, `maintenance-agent`. Advisor for `system-health-agent`.
- **Pricing**: $3 / input MTok, $15 / output MTok
- **Context**: 1M tokens · **Max output**: 64k tokens
- **Reliable knowledge cutoff**: Aug 2025
- **Extended thinking**: yes · **Adaptive thinking**: yes
- **Added**: 2026-05-05

### claude-haiku-4-5  (Haiku 4.5)
- **API ID / alias**: `claude-haiku-4-5`
- **Snapshot ID**: `claude-haiku-4-5-20251001`
- **AWS Bedrock ID**: `anthropic.claude-haiku-4-5-20251001-v1:0`
- **GCP Vertex AI ID**: `claude-haiku-4-5@20251001`
- **Role**: Lightweight diagnostic executor for `system-health-agent`. Fastest current Claude model with near-frontier intelligence.
- **Pricing**: $1 / input MTok, $5 / output MTok
- **Context**: 200k tokens · **Max output**: 64k tokens
- **Reliable knowledge cutoff**: Feb 2025
- **Extended thinking**: yes
- **Added**: 2026-05-05

---

## Disallowed

- **All Ollama / open-weight cloud models** (previously `devstral-2:123b-cloud`, `devstral-small-2:24b-cloud`, `glm-5.1:cloud`, `minimax-m2.5:cloud`, `minimax-m2.7:cloud`, `ministral-3:14b-cloud`, `gemma4:31b-cloud`) — removed 2026-05-05 in favour of Anthropic-only inference.
- **Deprecated Anthropic models** (`claude-sonnet-4-20250514`, `claude-opus-4-20250514`) — retired 2026-06-15 per <https://platform.claude.com/docs/en/about-claude/models/overview>.
- **Legacy 4.x models** (Opus 4.6, Opus 4.5, Opus 4.1, Sonnet 4.5) are still callable but **not preferred** — migrate to current generation when introducing new agents.

---

## Model assignment by agent

| Agent | Executor | Advisor |
|-------|----------|---------|
| `security-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` |
| `system-health-agent` | `claude-haiku-4-5` | `claude-sonnet-4-6` |
| `maintenance-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` |
| `requirements-agent` | `claude-opus-4-7` | `claude-opus-4-7` |
| `risk-analysis-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` |
| `solutions-agent` | `claude-sonnet-4-6` | `claude-opus-4-7` |
| `security-panel` | `claude-opus-4-7` | `claude-opus-4-7` |

Two agents (`requirements-agent`, `security-panel`) intentionally use Opus on both sides because their job *is* planning. The advisor pass on those agents functions as a fresh-context self-critique consistent with Anthropic's [evaluator-optimizer pattern](https://www.anthropic.com/engineering/building-effective-agents).

---

## Policy

1. **No unlisted models**: any `claude -p --model …` invocation referencing an unlisted model is a policy violation.
2. **Adding models requires approval**: new models must be added to this allowlist before use in any agent config.
3. **Pin snapshots for reproducibility**: production red-team baselines should pin the dated snapshot ID; only ad-hoc reviews should rely on aliases.
4. **Track deprecation**: when Anthropic announces a deprecation, set a migration deadline within the allowlist before the retirement date.

---

## Authentication

Set `ANTHROPIC_API_KEY` in the environment before invoking `claude -p`. Bedrock and Vertex routes use their respective platform credentials.

```bash
# Sanity check
claude --version
echo -n "${ANTHROPIC_API_KEY:+set}${ANTHROPIC_API_KEY:-unset}"
```
