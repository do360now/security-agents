# Ollama Model Allowlist

**Policy**: Only models with SHA-256 digests documented here may be referenced in agent configurations, Makefile, or invoked via `ollama run`/`ollama launch`.

**Verification**: Run `./verify-model-digest.sh <model-name>` to verify digest against this allowlist.

---

## Approved Models

### Local Models (GTX 1070 compatible - 8GB VRAM)

#### qwen2.5:3b
- **Purpose**: Fast executor for security-agent, solutions-agent, system-health-agent, maintenance-agent
- **Size**: 3B parameters (~2GB VRAM with Q4 quantization)
- **Model ID**: `357c53fb659c` (verify via `ollama list`)
- **Source**: Ollama library
- **Added**: 2026-04-19

#### qwen2.5:7b
- **Purpose**: Main executor for requirements-agent (stronger reasoning)
- **Size**: 7B parameters (~4GB VRAM with Q4_K_M quantization)
- **Model ID**: `845dbda0ea48` (verify via `ollama list`)
- **Source**: Ollama library
- **Added**: 2026-04-19

#### llama3.2:3b
- **Purpose**: Alternative fast executor
- **Size**: 3B parameters (~2GB VRAM)
- **Model ID**: `a80c4f17acd5` (verify via `ollama list`)
- **Source**: Ollama library
- **Added**: 2026-04-19

#### mistral:7b
- **Purpose**: Alternative 7B executor
- **Size**: 7B parameters (~4GB VRAM)
- **Model ID**: `6577803aa9a0` (verify via `ollama list`)
- **Source**: Ollama library
- **Added**: 2026-04-19

#### codellama:7b
- **Purpose**: Code-focused executor (not yet pulled)
- **Size**: 7B parameters (~4GB VRAM)
- **Model ID**: `<run 'ollama list' after pull>`
- **Source**: Ollama library
- **Added**: 2026-04-19

---

### Cloud Models (advisors)

#### devstral-2:123b-cloud
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
