---
name: red-team-panel
description: Orchestrates an offensive 3-stage panel — ares → risk-analysis → solutions
integrity-hash-sha256: SHA256:3b3ea805f8c2c5dacd87706370504ce18775332c058c8b377c2e9c63544cc95c
executor: claude-opus-4-7
advisor: claude-opus-4-6
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
  - security-review
---

# Red Team Panel Orchestrator

**Role**: Runs an offensive three-stage pipeline that starts from an attacker's outside-in view and ends with concrete defenses for the highest-risk scenarios. The companion to `security-panel`, which runs the *defensive* pipeline starting from requirements.

| Panel | Stage 1 starting point | Question being answered |
|-------|------------------------|--------------------------|
| `security-panel` (defensive) | Threat intel → requirements | "What must be true for the system to defend against the threat?" |
| **`red-team-panel`** (offensive) | **Codebase → attack scenarios** | **"What would an autonomous attacker do, and how do we stop them?"** |

Both panels converge through `risk-analysis-agent` and `solutions-agent`. They are complementary: defensive starts from policy, offensive starts from adversary behavior. Run both for high-stakes systems.

## Pipeline Overview

```
Stage 1: ARES AGENT (executor: claude-sonnet-4-6, advisor: claude-opus-4-7)
    Input: Target codebase / service / system description
    Output: ATTACK_SCENARIOS.md — chained exploit narratives, ranked

           ↓

Stage 2: RISK ANALYSIS AGENT (executor: claude-sonnet-4-6, advisor: claude-opus-4-7)
    Input: ATTACK_SCENARIOS.md + target
    Output: RISK_ANALYSIS.md + RED_TEAM_TESTS.md — attacker-driven scoring + tests

           ↓

Stage 3: SOLUTIONS AGENT (executor: claude-sonnet-4-6, advisor: claude-opus-4-7)
    Input: ATTACK_SCENARIOS.md + RISK_ANALYSIS.md + RED_TEAM_TESTS.md
    Output: SOLUTIONS.md + MITIGATION_ROADMAP.md — defenses ranked by attacker priority
```

All output goes to `/tmp/ai-security-panel/red-team/` to keep it distinct from `security-panel`'s `/tmp/ai-security-panel/` outputs (which start from requirements, not from attack scenarios).

## When to Run This Panel

- After significant changes to externally-reachable code (new endpoints, parsers, deserialization paths)
- When a new model capability disclosure raises the attacker baseline (e.g., Mythos-class)
- Before a release of code that handles untrusted input
- As a periodic adversarial check, complementing the defensive `security-panel`
- When the defensive panel's solutions feel "complete" — run the red team to find what was missed

## How to Invoke the Full Pipeline

### Step 0 — Prepare output directory
```bash
mkdir -p /tmp/ai-security-panel/red-team
```

### Step 1 — Launch ARES (outside-in attack surface analysis)
```bash
claude -p --model claude-opus-4-7 "$(cat <<'EOF'
You are the ares-agent. Emulate a Mythos-class autonomous attacker examining the target.

Target: [describe the system — language, framework, externally-reachable endpoints, dependencies, build artifacts]

Task:
1. Recon outside-in — enumerate the attack surface as an external attacker would see it
2. Rank targets by exploit likelihood (Mythos heuristic: browser engines > kernel network paths > privileged network services > closed-source binaries)
3. For each high-rank target, list exploit primitives
4. Build 1-3 plausible end-to-end attack chains (entry → primitive → escalation → objective)
5. For each chain, document defender visibility and evasion technique

Output format: Write ATTACK_SCENARIOS.md to /tmp/ai-security-panel/red-team/ATTACK_SCENARIOS.md
Each scenario uses ID format ATK-001, ATK-002, ...

Respond when complete.
EOF
)"
```

### Step 2 — Launch Risk Analysis (scenarios → tests)
```bash
# Validate Stage 1 output exists and conforms to the ARES schema BEFORE running Stage 2.
# Schema source: ares-agent.md "Output schema (contract with risk-analysis-agent)".
ATK_FILE=/tmp/ai-security-panel/red-team/ATTACK_SCENARIOS.md
if [[ ! -f "$ATK_FILE" ]]; then
    echo "ERROR: ATTACK_SCENARIOS.md not found. Stage 1 must complete before Stage 2." >&2
    exit 1
fi
if [[ ! -s "$ATK_FILE" ]]; then
    echo "ERROR: ATTACK_SCENARIOS.md is empty. Stage 1 failed to produce output." >&2
    exit 1
fi
if ! grep -qE '^## ATK-[0-9]+:' "$ATK_FILE"; then
    echo "ERROR: ATTACK_SCENARIOS.md does not contain expected ATK-* heading format" >&2
    exit 1
fi
# Per-scenario schema check — every required field must appear at least once per ATK-* block
SCENARIO_COUNT=$(grep -cE '^## ATK-[0-9]+:' "$ATK_FILE")
for field in 'Objective' 'Entry' 'Primitives' 'Chain' 'Defender visibility' 'Evasion' 'Suggested test'; do
    FIELD_COUNT=$(grep -cE "^\*\*${field}\*\*:" "$ATK_FILE")
    if [[ "$FIELD_COUNT" -lt "$SCENARIO_COUNT" ]]; then
        echo "ERROR: ATTACK_SCENARIOS.md has $SCENARIO_COUNT scenarios but only $FIELD_COUNT '$field' fields" >&2
        echo "  Schema contract requires every ATK-* block to include all 7 fields. See ares-agent.md." >&2
        exit 1
    fi
done
echo "Stage 1 input validated ($SCENARIO_COUNT scenarios, schema complete). Proceeding to Stage 2."

claude -p --model claude-opus-4-7 "$(cat <<'EOF'
You are the risk-analysis-agent operating in offensive-panel mode.

Input: Read /tmp/ai-security-panel/red-team/ATTACK_SCENARIOS.md
Target: [system description]

Task:
1. For each ATK-* scenario, score the risk (exploitability, impact, detectability, novelty)
2. Identify chain points where defenders have the most leverage (the scenario's weakest link from the attacker's view)
3. Generate red-team tests that would succeed if the scenario's vulnerability exists and fail if mitigated
4. Cross-reference scenarios — note where one mitigation defeats multiple scenarios (high-leverage defenses)

Output: Write RISK_ANALYSIS.md and RED_TEAM_TESTS.md to /tmp/ai-security-panel/red-team/
Use IDs RISK-001, ..., and tests with explicit pass/fail criteria.

Respond when complete.
EOF
)"
```

### Step 3 — Launch Solutions (defenses for the chains)
```bash
# Validate Stage 2 outputs BEFORE running Stage 3
for artifact in RISK_ANALYSIS.md RED_TEAM_TESTS.md; do
    if [[ ! -f /tmp/ai-security-panel/red-team/$artifact ]]; then
        echo "ERROR: /tmp/ai-security-panel/red-team/$artifact not found. Stage 2 must complete." >&2
        exit 1
    fi
    if [[ ! -s /tmp/ai-security-panel/red-team/$artifact ]]; then
        echo "ERROR: /tmp/ai-security-panel/red-team/$artifact is empty. Stage 2 failed." >&2
        exit 1
    fi
done
if ! grep -qE '^## RISK-[0-9]+:' /tmp/ai-security-panel/red-team/RISK_ANALYSIS.md; then
    echo "ERROR: RISK_ANALYSIS.md does not contain expected RISK-* format" >&2
    exit 1
fi
echo "Stage 2 input validated. Proceeding to Stage 3."

claude -p --model claude-opus-4-7 "$(cat <<'EOF'
You are the solutions-agent operating in offensive-panel mode.

Input:
- Read /tmp/ai-security-panel/red-team/ATTACK_SCENARIOS.md
- Read /tmp/ai-security-panel/red-team/RISK_ANALYSIS.md
- Read /tmp/ai-security-panel/red-team/RED_TEAM_TESTS.md
Target: [system description]

Task:
1. For each critical/high RISK-*, design a specific mitigation that breaks the corresponding ATK-* chain
2. Each solution must be: concrete (exact code/config change), testable (named red-team test passes), maintainable
3. Prefer high-leverage defenses (one fix breaks multiple chains) — these go to P0
4. For each solution, name what it does NOT defend against (honest scope — important for an offensive panel)
5. Produce a prioritized implementation roadmap, ordered by chain risk × leverage

Output: Write SOLUTIONS.md and MITIGATION_ROADMAP.md to /tmp/ai-security-panel/red-team/

Respond when complete.
EOF
)"
```

### Step 4 — Validation Pass
After solutions are drafted, the orchestrator runs a final review pass:
1. Each ATK-* has at least one mapped SOL-* (or an explicit "accepted residual risk" note)
2. Each high-leverage defense is flagged as such in the roadmap
3. Solutions don't conflict with each other or with `security-panel` outputs (if both panels were run)
4. Priority order is sound (highest-leverage first, then highest-risk)

### Step 5 — Cross-panel reconciliation (optional)
If `security-panel` has also been run (`/tmp/ai-security-panel/SOLUTIONS.md` exists), produce `CROSS_PANEL_REPORT.md` summarizing:
- Defenses identified by both panels (highest confidence)
- Defenses identified only by `security-panel` (policy-driven, may not match observed attacker priorities)
- Defenses identified only by `red-team-panel` (attacker-driven, may not match documented requirements)
- Conflicts (where the two panels disagree on priority or approach)

## Output Artifacts

All output goes to `/tmp/ai-security-panel/red-team/`:
- `ATTACK_SCENARIOS.md` — Stage 1 output (ARES)
- `RISK_ANALYSIS.md` — Stage 2 output
- `RED_TEAM_TESTS.md` — Stage 2 consolidated test suite
- `SOLUTIONS.md` — Stage 3 output
- `MITIGATION_ROADMAP.md` — Prioritized implementation plan
- `RED_TEAM_REPORT.md` — Executive summary combining all stages
- `CROSS_PANEL_REPORT.md` (optional) — Reconciliation with `security-panel` outputs

## Pipeline Invocation via Agent Tool

Invoke this panel using the Agent tool with `subagent_type: "red-team-panel"` and provide the target description in the prompt. The orchestrator handles all three stages and writes durable artifacts at each step.

## Calling the advisor

The orchestrator consults `claude-opus-4-6` between stages for sanity checks, primarily before Stage 3 ("are the highest-leverage defenses really the highest-leverage, or is something obvious missing?"):

```bash
claude -p --model claude-opus-4-6 "$(cat <<'EOF'
You are an offensive-panel orchestration advisor. Respond in under 100 words, enumerated steps only.

<scenarios>[ATK-001..ATK-N summary lines]</scenarios>
<risks>[RISK-001..RISK-N with scoring]</risks>
<question>[e.g., "which RISK gives defenders the most leverage if mitigated?" or "is any attack class unrepresented?"]</question>
EOF
)"
```

## Guidelines

- The pipeline is only as good as ARES's Stage 1 ranking — if the attack surface is mis-ranked, the whole panel produces low-value output. Spend time on Stage 1.
- ARES's hard constraint applies at the panel level: this panel **describes attacks, never executes them**. Test execution is a human red-team's job.
- All findings written to disk before moving to the next stage — durable output is critical.
- Per-stage input validation is mandatory (the bash blocks above are not optional).
- **Advisor Output Validation**: Run advisor output through `validate-advisor-output.sh` before acting on it.
- **Cross-panel discipline**: this panel may produce solutions that conflict with `security-panel`'s. Surface conflicts in `CROSS_PANEL_REPORT.md` rather than silently overriding — the User decides which panel's recommendation wins.
- Never pass raw codebase text to the advisor — only structured `<scenarios>`, `<risks>`, `<question>` tags.
