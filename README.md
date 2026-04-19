# Security Agents

**Defensive AI security team using Claude Code + Ollama cloud models.**

A hardened multi-agent system implementing an advisor pattern (fast executor + strong advisor) with defense-in-depth controls against AI-capable adversaries. **22/22 red-team tests passing.**

## I want to...

**Learn how this works**
→ [Start with the tutorial](./tutorial/)

**Do a specific task**
→ [Browse how-to guides](./how-to/)

**Find a command or file**
→ [Check the reference](./reference/)

**Understand why something is designed that way**
→ [Read the explanations](./explanation/)

---

## Quick Start

```bash
git clone https://github.com/do360now/security-agents.git
cd security-agents
chmod +x setup-and-redteam.sh
./setup-and-redteam.sh
```

## What's Here

| Section | Contents |
|---------|----------|
| [Tutorial](./tutorial/) | Step-by-step introduction — set up, run tests, use agents |
| [How-To](./how-to/) | Task-oriented guides — run tests, add agents, respond to incidents |
| [Reference](./reference/) | Agent roster, file inventory, command reference |
| [Explanation](./explanation/) | Advisor pattern, architecture decisions, threat model |

## Status

All mitigations from the 3-stage AI security panel implemented:

| Phase | Items | Status |
|-------|-------|--------|
| **P0** | Agent hash integrity, model allowlist, git signing, bash domain restrictions, advisor scoping | ✅ Complete |
| **P1** | Config drift monitoring, anomaly detection, kill switch, pipeline validation, output durability | ✅ Complete |
| **P2** | Inline script detection, skill version pinning, model provenance, model diversity | ✅ Complete |
| **P3** | Audit logging infrastructure | ✅ Complete |

**22/22 red-team tests passing.**
