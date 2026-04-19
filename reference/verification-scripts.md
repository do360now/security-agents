# Reference — Verification Scripts

All scripts that verify system integrity.

## All Agents

```bash
./verify-all-agents.sh
```

Computes SHA-256 of each agent's frontmatter (excluding the hash field itself) and compares against the stored `integrity-hash-sha256` value.

**Exit codes:** 0 = all pass, 1 = mismatch

**Output:**
```
PASS: .claude/agents/security-agent.md
PASS: .claude/agents/system-health-agent.md
...
All agents verified.
```

---

## Model Digest

```bash
./verify-model-digest.sh <model-name>:cloud
```

Runs `ollama show <model>` to get the SHA-256 digest and compares against `MODELS_ALLOWLIST.md`.

**Example:**
```bash
./verify-model-digest.sh devstral-2:123b-cloud
```

---

## Makefile Models

```bash
./validate-makefile-models.sh
```

Extracts all model names from `Makefile` and verifies each against `MODELS_ALLOWLIST.md`.

**Exit codes:** 0 = all in allowlist, 1 = unlisted model found

---

## Advisor Output Contract

```bash
./validate-advisor-output.sh < output.txt
# or
echo "1. Step one" | ./validate-advisor-output.sh
```

Validates advisor output against the contract:

| Check | What It Rejects |
|-------|----------------|
| Non-empty | Empty output |
| Enumerated steps | No `1.` numbered steps |
| No `Bash` | Raw bash command in response |
| No shell metacharacters | `&&`, `;`, `$()`, backticks, `\`, `|` |
| No file redirection | `> /`, `>> /`, `2> /` |
| No external URLs | `http://`, `https://` |

**Exit codes:** 0 = valid, 1 = contract violation

---

## Config Drift

```bash
./detect-config-drift.sh
```

Runs `git diff HEAD` against `.claude/settings.local.json` and all `.claude/agents/*.md` files. Fires an alert if any non-whitespace changes are detected.

**Exit codes:** 0 = no drift, 1 = drift detected

---

## Inline Script Detection

```bash
./pre-commit-inline-script-check.sh
```

Greps agent configs for dangerous command substitutions:
- `$(curl ...)`
- `$(wget ...)`
- `$(python ...)`
- `$(ruby ...)`
- `$(perl ...)`
- `base64 -d`

**Exit codes:** 0 = clean, 1 = dangerous pattern found

---

## Skill Versions

```bash
./verify-skill-versions.sh
```

Checks that all agents have pinned skill versions (exact version or commit hash, no floating `latest` or `*`).

**Exit codes:** 0 = all pinned, 1 = floating version found

---

## Setup and Red-Team

```bash
./setup-and-redteam.sh
```

Full bootstrap + run all 22 tests. Combines all verification scripts into one pass.

**Exit codes:** 0 = all pass, 1 = any failure
