# Threat Model

Assumptions about the threat landscape this system is designed against.

## Threat Actor: Mythos-Class AI Attacker

The primary threat is an autonomous AI model (like Anthropic's Mythos Preview) that can:

- Autonomously find and exploit zero-day vulnerabilities
- Chain multiple CVEs into working exploits
- Adapt its approach based on system defenses it encounters
- Operate at machine speed across many targets simultaneously

This threat is the reason the system was built. Defenses assume this class of attacker.

## Attacker Capabilities

| Capability | Implication for This System |
|------------|---------------------------|
| Read source code | Can find vulnerabilities without scanning tools |
| Write files | Can modify agent configs if permissions allow |
| Execute commands | Can run exploit code if Bash is unrestricted |
| Call models via API | Could use a malicious model if not on allowlist |
| Analyze agent behavior | Can identify which tools are available and exploit gaps |
| Wait and observe | Can take time to carefully plan attacks |

## Attack Surface

The system has several attack surfaces:

### Agent Configuration Files
An attacker who modifies `.claude/agents/*.md` can:
- Change the executor model to a malicious model
- Add tools to an agent's scope
- Remove or weaken restrictions

**Mitigation:** SHA-256 frontmatter hashes, git signed commits

### Advisor Calls
An attacker who influences what an agent sends to the advisor can:
- Inject malicious context into the advisor prompt
- Trick the advisor into returning exploit instructions

**Mitigation:** `cat <<'EOF'` scoping, output validation, model diversity

### Bash Execution
An agent with unrestricted Bash can:
- Download and execute malicious scripts
- Exfiltrate sensitive files via `curl`
- Modify settings to broaden permissions

**Mitigation:** Bash domain restrictions to localhost, limited command set

### Session Context
An attacker who controls what an agent reads can:
- Poison context with malicious content
- Manipulate the agent's understanding of the system

**Mitigation:** Structured `<task>` and `<transcript>` inputs, not raw transcript

## Security Boundaries

```
Internet
    │
    │ ollama.com (advisor calls only — WebFetch restricted)
    ▼
┌─────────────────────────────────────────┐
│  Host System                            │
│                                         │
│  .claude/agents/*.md  ← agent configs  │
│  .claude/settings.local.json            │
│                                         │
│  Bash (localhost only)  ← restricted    │
│                                         │
│  /tmp/ai-security-panel/ ← panel output│
│                                         │
│  /var/log/agent-audit/ ← audit logs   │
└─────────────────────────────────────────┘
```

## Trust Boundaries

| Boundary | Trust Level | Rationale |
|----------|-------------|-----------|
| Ollama cloud models | Medium trust | We control which models are on the allowlist |
| Agent configuration | High trust | Integrity hashes + git detect tampering |
| Advisor I/O | Low trust | Must validate all responses |
| Bash execution | Low trust | Restricted to prevent network access |
| External files read by agents | Low trust | Use structured inputs, not raw transcript |

## What We Assume the Attacker Cannot Do

- Break SHA-256 hashes (assumed computationally infeasible)
- Forge git signed commits without the private key
- Modify `/var/log/agent-audit/` if append-only enforced (`chattr +a`)
- Bypass `domain:localhost` Bash restrictions
- Use models not on the allowlist

## What Happens If the Attacker Succeeds at Each Stage

| Stage | Impact | Detection |
|-------|--------|-----------|
| Modifies agent file | Full system compromise | Hash mismatch, git diff alert |
| Adds malicious model | Pipelines run attacker code | Model not in allowlist |
| Gets unrestricted Bash | Host compromised | Audit logs, drift detection |
| Poisons advisor context | Advisor returns exploits | Output validation catches commands |
| Modifies settings | Permissions broadened | Drift detection alerts |

## See Also

- [Security Architecture](./security-architecture.md) — How the controls fit together
- [SECURITY_INCIDENT_RUNBOOK.md](../SECURITY_INCIDENT_RUNBOOK.md) — Kill switch if systems are compromised
- [MODELS_ALLOWLIST.md](../MODELS_ALLOWLIST.md) — Only approved models can be used
