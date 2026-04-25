# Claude Model Allowlist

**Policy**: Only Claude models documented here may be referenced in agent configurations, the `Makefile`, or invoked via `claude --model`, `claude -p --model`, or the Anthropic SDK from agent code.

**Verification**: Run `./verify-model-digest.sh <model-id>` to verify a model ID is on the allowlist.

---

## Attestation for hosted API models

Unlike locally-downloaded weights, Claude models are served by Anthropic's API and cannot be fingerprinted with a file-level SHA-256 digest. Integrity is instead established by:

1. **Model ID pinning** — every agent and Makefile target references an *exact* dated/versioned model ID (e.g., `claude-opus-4-7`, not `claude-opus-latest`). Anthropic does not mutate a pinned model ID after release.
2. **TLS channel verification** — API calls are made over TLS to `api.anthropic.com`; Anthropic's certificate is the root of trust for model identity.
3. **Allowlist enforcement** — this file is the single source of truth. Any model ID in agents or Makefile that is not listed here fails `validate-makefile-models.sh`.

SHA-256 digests are still used in this system for **agent frontmatter integrity** (`integrity-hash-sha256:` in each agent .md file, verified by `verify-all-agents.sh`).

---

## Approved Models

### claude-opus-4-7
- **Model ID**: `claude-opus-4-7`
- **Family**: Claude 4.x — Opus tier (flagship)
- **Purpose**: Advisor for security-agent / requirements-agent / risk-analysis-agent / solutions-agent; executor for security-panel orchestrator.
- **Capabilities**: Deepest reasoning, 1M-token context window, strongest on multi-step security analysis.
- **Added**: 2026-04-24

### claude-opus-4-6
- **Model ID**: `claude-opus-4-6`
- **Family**: Claude 4.x — Opus tier
- **Purpose**: Advisor for security-panel orchestrator (second-opinion on Opus 4.7 execution).
- **Capabilities**: Strong reasoning; prior-generation Opus flagship.
- **Added**: 2026-04-24

### claude-sonnet-4-6
- **Model ID**: `claude-sonnet-4-6`
- **Family**: Claude 4.x — Sonnet tier
- **Purpose**: Default executor for security-agent / requirements-agent / risk-analysis-agent / solutions-agent; advisor for system-health-agent / maintenance-agent.
- **Capabilities**: Balanced reasoning and throughput. Primary day-to-day executor.
- **Added**: 2026-04-24

### claude-haiku-4-5
- **Model ID**: `claude-haiku-4-5`
- **Family**: Claude 4.x — Haiku tier
- **Purpose**: Lightweight executor for system-health-agent / maintenance-agent.
- **Capabilities**: Fast, low-cost; appropriate for mechanical iteration (command invocation, file reads).
- **Added**: 2026-04-24

---

## Policy

1. **No unlisted models**: Any `claude --model`, `claude -p --model`, or Anthropic SDK call referencing an unlisted model ID is a policy violation.
2. **No floating aliases**: Do not use `claude-latest`, `claude-opus-latest`, etc. Always pin the exact dated ID.
3. **Adding models requires approval**: New Claude model releases must be added to this allowlist before being referenced in any agent or Makefile target.
4. **Deprecation**: When Anthropic announces retirement of a model, flag it here and migrate agents to the successor before the sunset date.

---

## Verification Commands

```bash
# Verify a specific model ID is in the allowlist
./verify-model-digest.sh claude-opus-4-7

# Verify all Makefile model references
./validate-makefile-models.sh

# Verify all approved models at once
for model in claude-opus-4-7 claude-opus-4-6 claude-sonnet-4-6 claude-haiku-4-5; do
    ./verify-model-digest.sh "$model"
done
```
