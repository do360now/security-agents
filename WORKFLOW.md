# WORKFLOW.md — Operator Workflows

Operator reference for running panels, scheduling recurring checks, and using advanced features.
For the architecture overview see `CLAUDE.md`. For agent internals see `.claude/agents/CLAUDE.md`.

---

## The advisor-pattern pipeline (Round 4, recommended; Round 5 extends to offensive panel)

### Why

Dispatching panel stages via `subagent_type` (Agent tool) causes the agent body to fully
replace Claude Code's default system prompt. That default prompt is what teaches Sonnet to
make real tool calls. Without it, stage agents hallucinate tool invocations as text rather
than executing them. The advisor-pattern invocation avoids this by using `--append-system-prompt-file`,
which keeps the default prompt and appends role-specific guidance.

Round 5 extended this to the offensive panel via the `attack-scenarios` stage — ARES now
runs through the same `panel/run_stage.sh` invocation as the three defensive stages. See
the four-stage offensive sequence below.

### How — defensive panel (three stages)

Each stage runs via `panel/run_stage.sh` with three flags enforcing the contract:

```bash
# Stage 1: generate requirements
panel/run_stage.sh requirements /tmp/ai-security-panel/<TARGET>/ \
  "Target: src/auth/ — Python Flask app, JWT auth, PostgreSQL. \
   Threat: Mythos-class autonomous AI attacker. \
   Generate concrete security requirements."

# Stage 2: risk analysis (reads REQUIREMENTS.json written by Stage 1)
panel/run_stage.sh risk-analysis /tmp/ai-security-panel/<TARGET>/ \
  "Read REQUIREMENTS.json from /tmp/ai-security-panel/<TARGET>/. \
   Analyze attack vectors, score risks, generate red-team tests."

# Stage 3: solutions (reads RISK_ANALYSIS.json and REQUIREMENTS.json)
panel/run_stage.sh solutions /tmp/ai-security-panel/<TARGET>/ \
  "Read RISK_ANALYSIS.json and REQUIREMENTS.json from /tmp/ai-security-panel/<TARGET>/. \
   Design SOL-* solutions and produce a 3-sprint roadmap."
```

### How — offensive panel (four stages, Round 5)

The offensive panel adds an `attack-scenarios` stage that runs through the same
`panel/run_stage.sh` invocation — see Round 5:

```bash
# Stage 1 (ARES): attack scenarios — outside-in adversary emulation
panel/run_stage.sh attack-scenarios /tmp/ai-security-panel/red-team/<TARGET>/ \
  "Target: src/ — Python Flask app, externally-reachable endpoints, PostgreSQL. \
   Emulate a Mythos-class attacker. Produce ranked ATK-* scenarios."

# Stage 2: risk analysis (reads ATTACK_SCENARIOS.json written by Stage 1)
panel/run_stage.sh risk-analysis /tmp/ai-security-panel/red-team/<TARGET>/ \
  "Read ATTACK_SCENARIOS.json from /tmp/ai-security-panel/red-team/<TARGET>/. \
   Treat each ATK-* as a requirement analog. Score risks, generate red-team tests."

# Stage 3: solutions (reads RISK_ANALYSIS.json from output dir)
panel/run_stage.sh solutions /tmp/ai-security-panel/red-team/<TARGET>/ \
  "Read RISK_ANALYSIS.json from /tmp/ai-security-panel/red-team/<TARGET>/. \
   Design SOL-* mitigations prioritized by attacker leverage, produce 3-sprint roadmap."

# Optional: cross-panel reconciliation with defensive panel outputs
# (see Section 3 below)
```

### Output contract

Each stage produces two artifacts in `<output_dir>`:

| Stage             | JSON artifact           | Markdown artifact      |
|-------------------|-------------------------|------------------------|
| attack-scenarios  | `ATTACK_SCENARIOS.json` | `ATTACK_SCENARIOS.md`  |
| requirements      | `REQUIREMENTS.json`     | `REQUIREMENTS.md`      |
| risk-analysis     | `RISK_ANALYSIS.json`    | `RISK_ANALYSIS.md`     |
| solutions         | `SOLUTIONS.json`        | `SOLUTIONS.md`         |

The JSON is the validated artifact (schema-checked at the boundary). The Markdown is the
human-readable view rendered automatically from the JSON.

If a stage's output does not conform to its schema in `panel/schemas/`, `panel/run_stage.sh`
exits non-zero and the orchestrator halts — implementing the action-schema pattern from
GitHub's multi-agent engineering guidance.

### Fallback

Subagent dispatch via `Agent(subagent_type: ...)` still works for one-off single-agent tasks
(e.g., `security-agent` auditing a specific module). For multi-stage panels, prefer the
advisor-pattern `panel/run_stage.sh` invocations above.

---

## 1. Run a defensive security panel

The security panel runs a three-stage pipeline: requirements → risk analysis → solutions.

```bash
# Interactive session — panel manages all three stages
claude --agent security-panel

# Headless / scripted
claude -p --agent security-panel --output-format json "$(cat <<'EOF'
Target: src/auth/ — Python Flask app, JWT auth, PostgreSQL, Redis session store
Threat: Mythos-class autonomous AI attacker with browser-engine and kernel exploit capability
Task: Run the full defensive pipeline. Write all artifacts to /tmp/ai-security-panel/.
EOF
)"
```

Artifacts written to `/tmp/ai-security-panel/`:
- `PLAN.md` — Stage 0 dispatch plan
- `REQUIREMENTS.md`, `REQUIREMENTS_SUMMARY.md` — Stage 1
- `STAGE_1_SUMMARY.md` — Stage 1 memory summary
- `RISK_ANALYSIS.md`, `RED_TEAM_TESTS.md` — Stage 2
- `STAGE_2_SUMMARY.md` — Stage 2 memory summary
- `SOLUTIONS.md`, `MITIGATION_ROADMAP.md` — Stage 3
- `STAGE_3_SUMMARY.md` — Stage 3 memory summary
- `EVALUATION.md` — Stage 3.5 rubric scores
- `PANEL_REPORT.md` — Executive summary

From another Claude Code session, invoke via the Agent tool:

```
Agent(
  description: "Defensive security panel for auth module",
  subagent_type: "security-panel",
  prompt: "Target: src/auth/. Threat: Mythos-class. Run full defensive pipeline."
)
```

---

## 2. Run an offensive red-team panel

The red-team panel runs: attack-scenarios (ARES) → risk-analysis → solutions.

### Recommended path — advisor-pattern (Round 5)

```bash
TARGET="my-service"
mkdir -p /tmp/ai-security-panel/red-team/${TARGET}

# Stage 1: ARES attack scenarios
panel/run_stage.sh attack-scenarios /tmp/ai-security-panel/red-team/${TARGET}/ \
  "Target: src/ — Python Flask app, JWT auth, PostgreSQL, externally-reachable REST API. \
   Emulate a Mythos-class attacker. Produce ranked ATK-* scenarios."

# Stage 2: risk analysis
panel/run_stage.sh risk-analysis /tmp/ai-security-panel/red-team/${TARGET}/ \
  "Read ATTACK_SCENARIOS.json from /tmp/ai-security-panel/red-team/${TARGET}/. \
   Treat each ATK-* as a requirement analog. Score risks, generate red-team tests."

# Stage 3: solutions
panel/run_stage.sh solutions /tmp/ai-security-panel/red-team/${TARGET}/ \
  "Read RISK_ANALYSIS.json from /tmp/ai-security-panel/red-team/${TARGET}/. \
   Design SOL-* mitigations prioritized by attacker leverage, produce 3-sprint roadmap."
```

### Alternative — interactive session

```bash
# Prepare output directory
mkdir -p /tmp/ai-security-panel/red-team

# Interactive session (panel manages all three stages)
claude --agent red-team-panel

# Headless
claude -p --agent red-team-panel --output-format json "$(cat <<'EOF'
Target: src/ — same Flask app. Emulate a Mythos-class attacker.
Task: Run the full offensive pipeline. Write all artifacts to /tmp/ai-security-panel/red-team/.
EOF
)"
```

Artifacts written to `/tmp/ai-security-panel/red-team/`:
- `ATTACK_SCENARIOS.json`, `ATTACK_SCENARIOS.md` — Stage 1 (ARES output, advisor-pattern)
- `PLAN.md` — Stage 0 dispatch plan (interactive session only)
- `STAGE_1_SUMMARY.md` — Stage 1 memory summary
- `RISK_ANALYSIS.json`, `RISK_ANALYSIS.md`, `RED_TEAM_TESTS.md` — Stage 2
- `STAGE_2_SUMMARY.md` — Stage 2 memory summary
- `SOLUTIONS.json`, `SOLUTIONS.md`, `MITIGATION_ROADMAP.md` — Stage 3
- `STAGE_3_SUMMARY.md` — Stage 3 memory summary
- `EVALUATION.md` — Stage 3.5 rubric scores (includes attacker-priority alignment criterion)
- `RED_TEAM_REPORT.md` — Executive summary

---

## 3. Run both panels and reconcile

Run both panels, then produce a cross-panel reconciliation report.

```bash
# Run defensive panel first
claude --agent security-panel

# Run offensive panel
claude --agent red-team-panel

# Reconcile — invoke red-team-panel with cross-panel flag
claude -p --agent red-team-panel "$(cat <<'EOF'
Both panels have completed.
Defensive artifacts: /tmp/ai-security-panel/SOLUTIONS.md
Offensive artifacts: /tmp/ai-security-panel/red-team/SOLUTIONS.md

Task: Produce CROSS_PANEL_REPORT.md at /tmp/ai-security-panel/red-team/CROSS_PANEL_REPORT.md
covering:
- Defenses identified by both panels (highest confidence)
- Defenses only in the defensive panel (policy-driven)
- Defenses only in the offensive panel (attacker-driven)
- Conflicts (panels disagree on priority or approach)
EOF
)"
```

---

## 4. Use Plan Mode for Stage 0

Plan Mode halts before any tool use and presents the dispatch plan for operator review. Use it before high-stakes runs.

```bash
# Defensive panel in plan mode
claude --agent security-panel --permission-mode plan

# Red-team panel in plan mode
claude --agent red-team-panel --permission-mode plan
```

The panel writes `PLAN.md` listing subagents, scope, and any fan-out branches, then pauses. Review the plan, edit it if needed, then exit plan mode and re-run without `--permission-mode plan` to execute.

For automated CI pipelines, omit `--permission-mode plan` and rely on the stage-input validation gates in the panel body instead.

---

## 5. Resume an interrupted panel run

Name the session at launch to enable resumption:

```bash
# Name the session
claude --agent security-panel -n sec-panel-2026-05-02

# Resume by name if the session drops
claude --resume sec-panel-2026-05-02
```

Subagent transcripts persist independently of the orchestrator session — if the orchestrator is interrupted mid-stage, the completed subagent work is preserved. The orchestrator checks for existing stage artifacts at each stage-input validation gate and skips stages whose artifacts already exist.

---

## 6. Parallel fan-out in Stage 2

Stage 2 fans out automatically based on item count when the panel runs as the main session.

**Rules:**
- 1-3 REQ-* (security-panel) or ATK-* (red-team-panel): single sequential `risk-analysis-agent` call
- 4-10 items: one `risk-analysis-agent` subagent per item, in parallel
- >10 items: batched into groups of ~5, one subagent per batch

Each parallel subagent writes to:
- `/tmp/ai-security-panel/parallel/risk-REQ-NNN.md` (security-panel)
- `/tmp/ai-security-panel/red-team/parallel/risk-ATK-NNN.md` (red-team-panel)

The orchestrator merges the per-item files into a single `RISK_ANALYSIS.md` and `RED_TEAM_TESTS.md`.

**Requirement:** parallel fan-out only works when the panel is the main Claude Code session:

```bash
claude --agent security-panel    # fan-out available
```

When invoked via `Agent(subagent_type: "security-panel", ...)` from another session, the panel cannot spawn further subagents and falls back to sequential execution.

---

## 7. Run agents in isolated worktrees

Two agents have `isolation: worktree` in their frontmatter: `ares-agent` and `solutions-agent`.

When Claude Code runs an agent with `isolation: worktree`, it creates a temporary git worktree for the session. The agent's file writes are scoped to that worktree rather than the main working tree. This prevents in-progress solution drafts or attack scenario files from polluting the live repo until they are reviewed and merged.

To use an isolated agent directly:

```bash
# solutions-agent runs in a worktree automatically
claude --agent solutions-agent

# ares-agent runs in a worktree automatically
claude --agent ares-agent
```

After the session completes, review the worktree artifacts and cherry-pick or merge as appropriate. The worktree is preserved until explicitly deleted.

---

## 8. Pipe a CVE feed into the requirements-agent

```bash
# Pipe a CVE JSON feed as stdin, get structured requirements back
cat cve-feed.json | claude -p --agent requirements-agent --output-format json

# Or from a file
claude -p --agent requirements-agent --output-format json < cve-2026-critical.json

# Example: fetch a CVE and pipe it
curl -s "https://cveawg.mitre.org/api/cve/CVE-2026-XXXX" | \
  claude -p --agent requirements-agent --output-format json
```

The requirements-agent reads stdin as threat intelligence input and writes `REQUIREMENTS.md` to the configured output path. The `--output-format json` flag returns structured JSON with the artifact paths and REQ count.

---

## 9. Schedule a recurring red-team pass

Three options for scheduled execution:

### Option (a) — Routines on claude.ai/code

Use the Routines interface at claude.ai/code to schedule a recurring agent run on a cron expression. Routines run in a managed environment with your stored credentials.

### Option (b) — GitHub Actions cron

```yaml
# .github/workflows/red-team-weekly.yml
on:
  schedule:
    - cron: '0 2 * * 1'   # every Monday 02:00 UTC
jobs:
  red-team:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run red-team panel
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          mkdir -p /tmp/ai-security-panel/red-team
          claude -p --agent red-team-panel --output-format json \
            "Target: $(pwd). Run full offensive pipeline."
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: red-team-${{ github.run_id }}
          path: /tmp/ai-security-panel/red-team/
```

### Option (c) — /loop for in-session polling

Use `/loop` inside an active Claude Code session to re-run the panel on an interval:

```
/loop 24h claude --agent red-team-panel
```

`/loop` is a Claude Code skill that reschedules itself after each run. It keeps session context warm across iterations and alerts you to changes between runs.

---

## 10. Add a Notification hook for long-running panels

Add a stop hook to `~/.claude/settings.json` to receive a desktop notification when a panel finishes:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "notify-send 'Claude Code' 'Panel run complete'"
          }
        ]
      }
    ]
  }
}
```

This is user-level config. Edit `~/.claude/settings.json` directly — do not add it to the project `.claude/settings.local.json`. The `notify-send` command is available on most Linux desktops (install via `apt install libnotify-bin` if missing). On macOS, replace with `osascript -e 'display notification "Panel run complete" with title "Claude Code"'`.

---

## 11. Use forks to try alternative defenses

Fork the current session to draft an alternative solution without affecting the main conversation:

```
/fork draft an alternative SOL-005 mitigation that doesn't require database schema changes
```

Forking creates a branch of the conversation where the alternative is explored in isolation. The main session is unaffected. When the fork produces a satisfactory alternative, copy the relevant `SOL-005` block back to the main session's `SOLUTIONS.md`.

Fork support requires `CLAUDE_CODE_FORK_SUBAGENT=1` in the environment:

```bash
export CLAUDE_CODE_FORK_SUBAGENT=1
claude --agent solutions-agent
```

---

## 12. Verify everything before/after a panel run

Run all verification scripts before starting a panel and after it completes:

```bash
# Before: verify agent integrity, model allowlist, and baseline
./verify-all-agents.sh && ./validate-makefile-models.sh && make red-team-summary

# After: same checks to confirm the panel run didn't modify agent files
./verify-all-agents.sh && ./validate-makefile-models.sh && make red-team-summary
```

`make red-team-summary` runs the automated red-team test suite and prints a PASS/FAIL count. A regression (fewer PASSes than before the panel run) indicates the panel modified files it should not have. Investigate with `git diff --stat` before proceeding.
