# Reference — Agent Roster

All agents in the system with their executor/advisor models and roles.

## Agent Overview

| Agent | Executor | Advisor | Role |
|-------|----------|---------|------|
| `security-agent` | devstral-small-2:24b | devstral-2:123b | Vulnerability scanning, code review |
| `system-health-agent` | ministral-3:14b | gemma4:31b | Process/resource diagnostics |
| `maintenance-agent` | minimax-m2.5 | devstral-2:123b | Updates, cleanup, optimization |
| `requirements-agent` | devstral-2:123b | glm-5.1 | Generate security requirements |
| `risk-analysis-agent` | glm-5.1 | devstral-2:123b | Attack vectors + red-team tests |
| `solutions-agent` | devstral-small-2:24b | glm-5.1 | Mitigation design |
| `security-panel` | devstral-2:123b | devstral-small-2:24b | 3-stage pipeline orchestrator |

## How to Invoke

All agents are invoked via the `Agent` tool:

```bash
Agent(subagent_type="<name>-agent", prompt="<task description>")
```

## Model Notes

All models use the Ollama `:cloud` or `:XXb-cloud` variant tags — no local GPU required.

| Model | Family | Use Case |
|-------|--------|----------|
| `devstral-2:123b-cloud` | Devstral | Primary executor, panel orchestrator |
| `devstral-small-2:24b-cloud` | Devstral | Fast executor, security scanning |
| `glm-5.1:cloud` | GLM | Risk analysis, requirements advisor |
| `minimax-m2.5:cloud` | MiniMax | Maintenance executor |
| `minimax-m2.7:cloud` | MiniMax | Alternative executor |
| `ministral-3:14b-cloud` | Ministral | System health executor |
| `gemma4:31b-cloud` | Gemma | System health advisor |

## Tool Scopes

Each agent has a defined tool scope. Using tools outside scope triggers anomaly alerts:

| Agent | Expected Tools | Alert on |
|-------|---------------|----------|
| security-agent | Read, Grep | Any Write, Edit, Bash |
| system-health-agent | Read, Grep, Bash, Glob | Any Write, Edit, WebFetch |
| maintenance-agent | Read, Write, Edit, Bash, Grep, Glob | — (full scope) |
| requirements-agent | Read, Write, Bash, Grep, Glob, WebFetch, WebSearch | — (full scope) |
| risk-analysis-agent | Read, Write, Bash, Grep, Glob, WebFetch, WebSearch | — (full scope) |
| solutions-agent | Read, Write, Edit, Bash, Grep, Glob, WebFetch, WebSearch | — (full scope) |
| security-panel | Read, Write, Edit, Bash, Grep, Glob, WebFetch, WebSearch | — (full scope) |
