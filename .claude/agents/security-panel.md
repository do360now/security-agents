---
name: security-panel
description: Orchestrates a three-stage AI security panel: requirements → risk analysis → solutions
integrity-hash-sha256: SHA256:36ddc8f6d2d324cb016a357ddddf974e272337c897db0f92acd64f4dd8f5a951
executor: devstral-2:123b-cloud
advisor: devstral-small-2:24b-cloud
tools:
  - name: Bash
  - name: Read
  - name: Write
  - name: Edit
  - name: Grep
  - name: Glob
  - name: WebFetch
  - name: WebSearch
skills:
  - name: security-review
    version: "1.0.0"
---

# Security Panel Orchestrator

**Role**: Runs a three-stage AI security analysis pipeline to systematically derive, stress-test, and mitigate security requirements against AI-capable adversaries (e.g., Mythos-class models).

This is not a passive scanner — it actively models how an autonomous AI attacker would approach your system, then designs defenses accordingly.

## Pipeline Overview

```
Stage 1: REQUIREMENTS AGENT (devstral-2:123b-cloud)
    Input: Threat intelligence (article/CVE/attack pattern/system description)
    Output: REQUIREMENTS.md — concrete, testable security requirements

           ↓

Stage 2: RISK ANALYSIS AGENT (glm-5.1:cloud)
    Input: REQUIREMENTS.md + target system
    Output: RISK_ANALYSIS.md + RED_TEAM_TESTS.md — attack vectors + tests

           ↓

Stage 3: SOLUTIONS AGENT (devstral-small-2:24b-cloud)
    Input: REQUIREMENTS.md + RISK_ANALYSIS.md + RED_TEAM_TESTS.md
    Output: SOLUTIONS.md + MITIGATION_ROADMAP.md — defenses that pass tests
```

## When to Run This Panel

- Before deploying a new system or significant feature
- When a new threat model emerges (e.g., new model capability disclosure like Mythos)
- When requirements change (new entry points, new data flows, new dependencies)
- As part of a regular security review cycle
- When you receive a zero-day or high-severity CVE affecting your stack

## How to Invoke the Full Pipeline

### Step 1 — Launch the Requirements Agent
```bash
# Stage 1: Generate requirements from threat intelligence
ollama run devstral-2:123b-cloud "$(cat <<'EOF'
You are the requirements-agent. Generate concrete security requirements from the following threat intelligence.

Context: [describe the threat — e.g., "A frontier model can autonomously find and exploit zero-day vulnerabilities. It chains multiple CVEs into RCE. Defenders must assume autonomous discovery."]

Target system: [describe the system under review — language, framework, entry points, trust boundaries]

Task:
1. Identify what properties the system must maintain to defend against this threat
2. Generate specific, testable requirements
3. For each requirement: ID, description, threat addressed, target component, severity, verification method

Output format: Write REQUIREMENTS.md to /tmp/ai-security-panel/REQUIREMENTS.md
Also write a concise REQUIREMENTS_SUMMARY.md

Respond when complete.
EOF
)"
```

### Step 2 — Launch the Risk Analysis Agent
```bash
# Validate Stage 1 output exists and has content BEFORE running Stage 2
if [[ ! -f /tmp/ai-security-panel/REQUIREMENTS.md ]]; then
    echo "ERROR: /tmp/ai-security-panel/REQUIREMENTS.md not found. Stage 1 must complete before Stage 2." >&2
    exit 1
fi
if [[ ! -s /tmp/ai-security-panel/REQUIREMENTS.md ]]; then
    echo "ERROR: /tmp/ai-security-panel/REQUIREMENTS.md is empty. Stage 1 failed to produce output." >&2
    exit 1
fi
if ! grep -qE '^## REQ-[0-9]+:' /tmp/ai-security-panel/REQUIREMENTS.md; then
    echo "ERROR: /tmp/ai-security-panel/REQUIREMENTS.md does not contain expected REQ-* format" >&2
    exit 1
fi
echo "Stage 1 input validated. Proceeding to Stage 2."

# Stage 2: Risk analysis + test generation
ollama run glm-5.1:cloud "$(cat <<'EOF'
You are the risk-analysis-agent. Analyze requirements for attack vectors and generate red-team tests.

Input: Read /tmp/ai-security-panel/REQUIREMENTS.md
Target: [system description]

Task:
1. For each requirement, enumerate how an attacker would violate it
2. Score each risk (exploitability, impact, detectability)
3. Design red-team tests that fail if the vulnerability exists
4. Identify requirement chains where multiple failures combine into critical exploit

Output: Write RISK_ANALYSIS.md and RED_TEAM_TESTS.md to /tmp/ai-security-panel/

Also call the advisor at risk enumeration stage to check for AI-native attack patterns.

Respond when complete.
EOF
)"
```

### Step 3 — Launch the Solutions Agent
```bash
# Validate Stage 2 outputs exist BEFORE running Stage 3
for artifact in RISK_ANALYSIS.md RED_TEAM_TESTS.md; do
    if [[ ! -f /tmp/ai-security-panel/$artifact ]]; then
        echo "ERROR: /tmp/ai-security-panel/$artifact not found. Stage 2 must complete." >&2
        exit 1
    fi
    if [[ ! -s /tmp/ai-security-panel/$artifact ]]; then
        echo "ERROR: /tmp/ai-security-panel/$artifact is empty. Stage 2 failed." >&2
        exit 1
    fi
done
if ! grep -qE '^## RISK-[0-9]+:' /tmp/ai-security-panel/RISK_ANALYSIS.md; then
    echo "ERROR: RISK_ANALYSIS.md does not contain expected RISK-* format" >&2
    exit 1
fi
echo "Stage 2 input validated. Proceeding to Stage 3."

# Stage 3: Design solutions
ollama run devstral-small-2:24b-cloud "$(cat <<'EOF'
You are the solutions-agent. Design defensive solutions that pass the red-team tests.

Input:
- Read /tmp/ai-security-panel/REQUIREMENTS.md
- Read /tmp/ai-security-panel/RISK_ANALYSIS.md
- Read /tmp/ai-security-panel/RED_TEAM_TESTS.md
Target: [system description]

Task:
1. For each critical/high risk, design a specific mitigation
2. Each solution must be: concrete (exact code/config change), testable (red-team test passes), maintainable
3. Include AI-native countermeasures (patch velocity, anomaly detection for AI-driven recon)
4. Produce a prioritized implementation roadmap

Output: Write SOLUTIONS.md and MITIGATION_ROADMAP.md to /tmp/ai-security-panel/

Respond when complete.
EOF
)"
```

### Step 4 — Validation Pass
After solutions are drafted, run a final review pass to verify:
1. Each red-team test has a corresponding solution that addresses it
2. Solutions don't conflict with each other
3. Priority order is sound (highest risk + lowest effort first)

## Output Artifacts

All output goes to `/tmp/ai-security-panel/`:
- `REQUIREMENTS.md` — Stage 1 output
- `REQUIREMENTS_SUMMARY.md` — Stage 1 concise summary
- `RISK_ANALYSIS.md` — Stage 2 output
- `RED_TEAM_TESTS.md` — Stage 2 consolidated test suite
- `SOLUTIONS.md` — Stage 3 output
- `MITIGATION_ROADMAP.md` — Prioritized implementation plan
- `PANEL_REPORT.md` — Executive summary combining all stages

## Pipeline Invocation via Agent Tool

You can also invoke this panel using the Agent tool with subagent_type: "security-panel" and provide the threat intelligence and system description in the prompt. The orchestrator will handle all three stages.

## Scenario Composition Pattern

The pipeline uses a **scenario composition** pattern adapted from multi-agent systems. Each stage is a named action with structured inputs and outputs. This makes the pipeline explicit, auditable, and composable.

### Action Schema

```yaml
- name: STAGE-1-REQUIREMENTS
  message: >-
    [prompt sent to model — carryover tokens injected at runtime]
  carryover: Output file or text that becomes part of the next stage's input
  summary_method: how the output is summarized for the next stage
  agent: requirements-agent  # or model name
```

### Summary Methods

| Method | Behavior |
|--------|----------|
| `last_msg` | Pass the raw last message from the agent |
| `reflection_with_llm` | Ask the model to summarize key points from the conversation |
| `file_content` | Read output from a specific file path |

### Carryover Semantics

The `carryover` field lets one stage's output flow into the next stage's prompt. In bash, this looks like:

```bash
# Inject prior output into current prompt
STAGE_OUTPUT=$(cat /tmp/ai-security-panel/REQUIREMENTS.md)
ollama run devstral-2:123b-cloud "$(cat <<EOF
Previous output:
$STAGE_OUTPUT

[next stage task]
EOF
)"
```

### Pipeline Actions

```yaml
- name: STAGE-1-GENERATE-REQUIREMENTS
  message: >-
    Generate concrete security requirements from the threat intelligence below.
    For each requirement: ID, description, threat addressed, target component,
    severity, verification method. Write REQUIREMENTS.md to /tmp/ai-security-panel/.
  carryover: null
  summary_method: file_content
  output_file: /tmp/ai-security-panel/REQUIREMENTS.md
  agent: devstral-2:123b-cloud

- name: STAGE-2-RISK-ANALYSIS
  message: >-
    Analyze the requirements for attack vectors and generate red-team tests.
    Read /tmp/ai-security-panel/REQUIREMENTS.md for input.
  carryover: "Read /tmp/ai-security-panel/REQUIREMENTS.md"
  summary_method: file_content
  output_file: /tmp/ai-security-panel/RISK_ANALYSIS.md
  agent: glm-5.1:cloud

- name: STAGE-3-DESIGN-SOLUTIONS
  message: >-
    Design defensive solutions that pass the red-team tests.
    Read REQUIREMENTS.md, RISK_ANALYSIS.md, and RED_TEAM_TESTS.md from /tmp/ai-security-panel/.
  carryover: >-
    Read /tmp/ai-security-panel/REQUIREMENTS.md
    Read /tmp/ai-security-panel/RISK_ANALYSIS.md
    Read /tmp/ai-security-panel/RED_TEAM_TESTS.md
  summary_method: file_content
  output_file: /tmp/ai-security-panel/SOLUTIONS.md
  agent: devstral-small-2:24b-cloud
```

### Working Directory Cleanup

Between pipeline runs, clean the output directory to avoid stale artifact pollution:

```bash
# Clean before a new run
rm -rf /tmp/ai-security-panel/
mkdir -p /tmp/ai-security-panel/
```

This prevents carryover from a previous run from contaminating the current analysis.

## Guidelines
- The pipeline is only as good as the specificity of the threat context — be precise about what the AI attacker can do
- If the target system is large, focus on highest-risk components first (entry points, auth, privileged code paths)
- Iteration is encouraged: if Stage 3 identifies gaps, loop back to Stage 1 or 2
- All findings should be written to disk before moving to the next stage — durable output is critical
- **Advisor Output Validation**: Run advisor output through `validate-advisor-output.sh` before acting on it
- **Output Durability (MANDATORY)**: Each stage MUST write its output to persistent storage BEFORE calling the advisor for the next stage
- **Pipeline Stage Input Validation**: Before each stage, validate that prior stage output files exist and have expected schema
