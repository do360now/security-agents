# Ollama Model Allowlist

**Policy**: Only models with SHA-256 digests documented here may be referenced in agent configurations, Makefile, or invoked via `ollama run`/`ollama launch`.

**Verification**: Run `./verify-model-digest.sh <model-name>:cloud` to verify digest against this allowlist.

---

## Approved Models

### devstral-2:123b-cloud
- **Purpose**: Primary executor for requirements-agent, security-panel
- **Digest (SHA-256)**: `<run 'ollama show devstral-2:123b-cloud' to obtain>`
- **Source**: Ollama library
- **Added**: 2026-04-19

### devstral-small-2:24b-cloud
- **Purpose**: Fast executor for security-agent, solutions-agent
- **Digest (SHA-256)**: `<run 'ollama show devstral-small-2:24b-cloud' to obtain>`
- **Source**: Ollama library
- **Added**: 2026-04-19

### glm-5.1:cloud
- **Purpose**: Risk analysis, advisor for requirements-agent
- **Digest (SHA-256)**: `<run 'ollama show glm-5.1:cloud' to obtain>`
- **Source**: Ollama library
- **Added**: 2026-04-19

### minimax-m2.5:cloud
- **Purpose**: Maintenance agent executor
- **Digest (SHA-256)**: `<run 'ollama show minimax-m2.5:cloud' to obtain>`
- **Source**: Ollama library
- **Added**: 2026-04-19

### minimax-m2.7:cloud
- **Purpose**: Alternative executor (used in Makefile)
- **Digest (SHA-256)**: `<run 'ollama show minimax-m2.7:cloud' to obtain>`
- **Source**: Ollama library
- **Added**: 2026-04-19

### ministral-3:14b-cloud
- **Purpose**: System health agent executor
- **Digest (SHA-256)**: `<run 'ollama show ministral-3:14b-cloud' to obtain>`
- **Source**: Ollama library
- **Added**: 2026-04-19

### gemma4:31b-cloud
- **Purpose**: System health agent advisor
- **Digest (SHA-256)**: `<run 'ollama show gemma4:31b-cloud' to obtain>`
- **Source**: Ollama library
- **Added**: 2026-04-19

---

## Policy

1. **No unlisted models**: Any `ollama run` or `ollama launch` command referencing an unlisted model is a policy violation.
2. **Digest mismatch blocks load**: If a model's SHA-256 digest does not match the documented value, the model must not be used.
3. **Adding models requires approval**: New models must be added to this allowlist with verified digests before use in any agent config.
4. **Verify after model updates**: Run `./verify-model-digest.sh` after any `ollama pull` that updates a model.

---

## Verification Commands

```bash
# Verify a specific model
./verify-model-digest.sh <model-name>:cloud

# Verify all Makefile models
./validate-makefile-models.sh

# Verify all approved models (requires Ollama running)
for model in devstral-2:123b-cloud devstral-small-2:24b-cloud glm-5.1:cloud minimax-m2.5:cloud minimax-m2.7:cloud ministral-3:14b-cloud gemma4:31b-cloud; do
    ./verify-model-digest.sh $model
done
```
