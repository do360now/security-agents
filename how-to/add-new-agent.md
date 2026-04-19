# How to Add a New Agent

Extend the system with a custom agent.

## Step 1 — Create the Agent File

Create `.claude/agents/<name>-agent.md` with frontmatter:

```yaml
---
name: my-agent
description: One-line purpose shown in agent picker
integrity-hash-sha256: SHA256:<placeholder>
executor: <fast-model>:cloud
advisor: <strong-model>:cloud
tools:
  - name: Bash
  - name: Read
  - name: Write
  - name: Edit
  - name: Grep
  - name: Glob
skills: []
---

# My Agent

## Responsibilities

Describe what this agent does and when to invoke it.

## Advisor-call Timing

When should this agent consult its advisor?

1. **After initial recon** — after file reads and listing commands
2. **When stuck** — recurring errors or approach not converging
3. **Before declaring done** — output written to disk first

## Example Advisor Call

```bash
ollama run <advisor>:cloud "$(cat <<'EOF'
You are a <domain> advisor. Respond in under 100 words, enumerated steps only.

<task>[current task]</task>
<transcript>[what the agent has found so far]</transcript>
What should the agent do next?
EOF
)"
```

## Guidelines

- Write durable output to disk before the final advisor call
- Run `validate-advisor-output.sh` on advisor responses before acting
- Use structured `<tag>` inputs in advisor calls, not raw transcript
```

## Step 2 — Verify Model Names

Ensure the models you specified are in `MODELS_ALLOWLIST.md`:

```bash
grep "<model-name>:cloud" MODELS_ALLOWLIST.md
```

If not found, add it with its SHA-256 digest.

## Step 3 — Compute the Integrity Hash

After creating the file:

```bash
./verify-all-agents.sh
```

This computes SHA-256 of the frontmatter and outputs the correct hash.

## Step 4 — Update the Hash in the File

Edit your agent file, replacing `<placeholder>` with the hash from step 3:

```yaml
integrity-hash-sha256: SHA256:<hash-from-step-3>
```

## Step 5 — Verify

```bash
./verify-all-agents.sh
```

Your new agent should pass. All 22 tests should still pass.

## Rules

1. **Executor and advisor must be different models** — same-model pairs enable context poisoning
2. **Pin skill versions** — use exact version or commit hash, never `latest`
3. **Use `cat <<'EOF'`** — never `cat <<EOF` (variable expansion leaks into advisor input)
4. **Write output before advisor call** — so a timeout mid-advice doesn't lose work

## Adding Skills

If your agent uses skills, verify version pinning:

```bash
./verify-skill-versions.sh
```
