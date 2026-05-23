#!/usr/bin/env bash
# panel/run_stage.sh — Run a single stage of the security panel pipeline.
#
# Usage:
#   panel/run_stage.sh <stage> <output_dir> "<task_prompt>"
#
# <stage>        : attack-scenarios | requirements | risk-analysis | solutions | evaluator | cross-panel
# <output_dir>   : absolute path to output directory, e.g. /tmp/ai-security-panel/<TARGET>/
# <task_prompt>  : orchestrator-supplied task description passed as the user prompt
#
# The script invokes:
#   claude -p --append-system-prompt-file panel/system-prompts/<stage>.md \
#              --output-format json \
#              --json-schema panel/schemas/<stage>.schema.json \
#              --allowedTools <per-stage tool list> \
#              --model <per-stage model> \
#              "<task_prompt>"
#
# Per-stage model: claude-sonnet-4-6 for all stages EXCEPT the evaluator, which
# runs claude-opus-4-7 so it never grades output produced by its own model
# (anti-self-preference — see STAGE_MODEL below).
#
# Output:
#   <output_dir>/<ARTIFACT>.json  — validated JSON artifact
#   <output_dir>/<ARTIFACT>.md    — human-readable markdown rendering
#
# Exit codes:
#   0 — stage completed and output is valid
#   1 — argument or file error
#   2 — stage execution failed or schema validation error returned by Claude Code

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve the script's own directory so relative paths work from any cwd
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
if [[ $# -lt 3 ]]; then
    echo "Usage: panel/run_stage.sh <stage> <output_dir> \"<task_prompt>\"" >&2
    echo "  stage: attack-scenarios | requirements | risk-analysis | solutions | evaluator | cross-panel" >&2
    exit 1
fi

STAGE="$1"
OUTPUT_DIR="$2"
TASK_PROMPT="$3"

# ---------------------------------------------------------------------------
# Validate stage name and resolve file paths
# ---------------------------------------------------------------------------
# Default model for every stage. Individual stages may override STAGE_MODEL below.
# The evaluator deliberately runs on a DIFFERENT model than the solutions-agent it
# grades (claude-sonnet-4-6): a grader that shares the author's model exhibits
# measurable self-preference (Claude Mythos Preview System Card §4.3.5 — Claude
# graders rate Claude-authored transcripts more leniently, worst for same-model
# pairings). Opus 4.7 also showed the lowest self-favoritism of tested models and
# is the stronger judge. See MODELS_ALLOWLIST.md for approved IDs.
STAGE_MODEL="claude-sonnet-4-6"

# Whether to prepend the shared safety preamble (panel/system-prompts/_safety-preamble.md)
# to this stage's system prompt. Enabled for write-capable generative stages, where the
# Mythos card §4.2.2.2 safety/honesty prompt measurably reduced reckless and reward-hacking
# behavior. Read-only stages (evaluator, cross-panel) do not need it.
PREPEND_SAFETY_PREAMBLE=0

case "$STAGE" in
    attack-scenarios)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/attack-scenarios.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/attack-scenarios.md"
        ARTIFACT_BASE="ATTACK_SCENARIOS"
        # ARES may fetch CVE / threat intel context
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob,WebFetch"
        PREPEND_SAFETY_PREAMBLE=1
        ;;
    requirements)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/requirements.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/requirements.md"
        ARTIFACT_BASE="REQUIREMENTS"
        # requirements may benefit from WebFetch for CVE lookups
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob,WebFetch"
        PREPEND_SAFETY_PREAMBLE=1
        ;;
    risk-analysis)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/risk-analysis.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/risk-analysis.md"
        ARTIFACT_BASE="RISK_ANALYSIS"
        # risk-analysis reads local files only; no web tools needed
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob"
        PREPEND_SAFETY_PREAMBLE=1
        ;;
    solutions)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/solutions.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/solutions.md"
        ARTIFACT_BASE="SOLUTIONS"
        # solutions reads local files only; no web tools needed
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob"
        PREPEND_SAFETY_PREAMBLE=1
        ;;
    evaluator)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/evaluator.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/evaluator.md"
        ARTIFACT_BASE="EVALUATION"
        # evaluator reads only — no Write, no WebFetch
        ALLOWED_TOOLS="Read,Bash,Grep,Glob"
        # Cross-model grading: the evaluator must not run the same model as the
        # solutions-agent whose output it grades (anti-self-preference, §4.3.5).
        STAGE_MODEL="claude-opus-4-7"
        ;;
    cross-panel)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/cross-panel.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/cross-panel.md"
        ARTIFACT_BASE="CROSS_PANEL_REPORT"
        # cross-panel reads from two locations — needs Read, no Write
        ALLOWED_TOOLS="Read,Bash,Grep,Glob"
        ;;
    *)
        echo "ERROR: Unknown stage '${STAGE}'. Must be: attack-scenarios | requirements | risk-analysis | solutions | evaluator | cross-panel" >&2
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Verify required files exist
# ---------------------------------------------------------------------------
if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "ERROR: Schema file not found: ${SCHEMA_FILE}" >&2
    exit 1
fi

if [[ ! -f "$SYSPROMPT_FILE" ]]; then
    echo "ERROR: System prompt file not found: ${SYSPROMPT_FILE}" >&2
    exit 1
fi

# Verify jq is available (needed for result extraction and validation)
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not found in PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Event log — append-only JSONL at <output_dir>/events.jsonl
# Used by panel/wake.sh to resume dropped panel runs.
# ---------------------------------------------------------------------------
emit_event() {
    local event_type="$1"   # stage_started | stage_completed | stage_failed
    local extra_json="${2:-}"  # optional comma-prefixed JSON fields, e.g. ',"artifact_path":"..."'

    local event_log="${OUTPUT_DIR}/events.jsonl"
    mkdir -p "$OUTPUT_DIR"
    chmod 700 "$OUTPUT_DIR" 2>/dev/null || true

    # Ownership check: if the file exists, verify it is owned by the current UID.
    if [[ -f "$event_log" ]]; then
        local file_uid current_uid
        file_uid="$(stat -c '%u' "$event_log")"
        current_uid="$(id -u)"
        if [[ "$file_uid" != "$current_uid" ]]; then
            printf 'ERROR: events_jsonl_ownership_mismatch: %s is owned by uid %s but current uid is %s\n' \
                "$event_log" "$file_uid" "$current_uid" >&2
            exit 2
        fi
    fi

    local next_id=1
    if [[ -f "$event_log" ]]; then
        next_id=$(( $(wc -l < "$event_log") + 1 ))
    fi

    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # task_prompt_hash uses sha256sum of the task prompt
    local prompt_hash
    prompt_hash="$(printf '%s' "${TASK_PROMPT:-}" | sha256sum | cut -d' ' -f1)"

    # Build the record. output_dir and stage are always present.
    # Escape output_dir for JSON (it should not contain " or \ in practice but be safe).
    local safe_dir="${OUTPUT_DIR//\\/\\\\}"
    safe_dir="${safe_dir//\"/\\\"}"

    printf '{"id":%d,"timestamp":"%s","event_type":"%s","stage":"%s","output_dir":"%s","task_prompt_hash":"%s"%s}\n' \
        "$next_id" "$ts" "$event_type" "$STAGE" "$safe_dir" "$prompt_hash" "$extra_json" \
        >> "$event_log"

    chmod 600 "$event_log" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Prepare output directory
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR"
emit_event "stage_started"

JSON_OUTPUT="${OUTPUT_DIR}/${ARTIFACT_BASE}.json"
MD_OUTPUT="${OUTPUT_DIR}/${ARTIFACT_BASE}.md"

echo "========================================"
echo "panel/run_stage.sh — Stage: ${STAGE}"
echo "Output dir:  ${OUTPUT_DIR}"
echo "JSON output: ${JSON_OUTPUT}"
echo "MD output:   ${MD_OUTPUT}"
echo "========================================"

# ---------------------------------------------------------------------------
# Pre-flight integrity gate + flock
# ---------------------------------------------------------------------------
# Export emit_event so it is callable from within the subshell.
export -f emit_event
# Temp files to pass structured outputs out of the subshell.
_RAW_RESPONSE_FILE="$(mktemp)"
# Holds the safety-preamble + stage-prompt concatenation for write-capable stages.
# Populated inside the subshell only when PREPEND_SAFETY_PREAMBLE=1; harmless if unused.
_COMBINED_SYSPROMPT_FILE="$(mktemp)"
_SUBSHELL_EXIT_CODE=0

(
    flock -x 200

    # --- Pre-flight: agent integrity check ---
    if ! "${REPO_ROOT}/verify-all-agents.sh" >/dev/null 2>&1; then
        emit_event "stage_failed" ',"error_reason":"agent_integrity_check_failed"' || true
        printf 'ERROR: Pre-flight failed: agent_integrity_check_failed\n' >&2
        exit 2
    fi

    # --- Pre-flight: panel file integrity check ---
    if ! "${REPO_ROOT}/panel/verify-panel-files.sh" >/dev/null 2>&1; then
        emit_event "stage_failed" ',"error_reason":"panel_files_integrity_check_failed"' || true
        printf 'ERROR: Pre-flight failed: panel_files_integrity_check_failed\n' >&2
        exit 2
    fi

    # --- Optionally prepend the shared safety preamble (write-capable stages) ---
    # Done after the integrity gates so a tampered preamble is caught by
    # verify-panel-files.sh above before its content can reach the model.
    sysprompt_arg="${SYSPROMPT_FILE}"
    if [[ "$PREPEND_SAFETY_PREAMBLE" == "1" ]]; then
        safety_preamble="${REPO_ROOT}/panel/system-prompts/_safety-preamble.md"
        if [[ ! -f "$safety_preamble" ]]; then
            emit_event "stage_failed" ',"error_reason":"safety_preamble_missing"' || true
            printf 'ERROR: Pre-flight failed: safety_preamble_missing\n' >&2
            exit 2
        fi
        cat "$safety_preamble" "${SYSPROMPT_FILE}" > "${_COMBINED_SYSPROMPT_FILE}"
        sysprompt_arg="${_COMBINED_SYSPROMPT_FILE}"
    fi

    # --- Build and run the claude -p invocation ---
    local_schema_content="$(cat "${SCHEMA_FILE}")"

    claude -p \
        --append-system-prompt-file "${sysprompt_arg}" \
        --output-format json \
        --json-schema "${local_schema_content}" \
        --allowedTools "${ALLOWED_TOOLS}" \
        --model "${STAGE_MODEL}" \
        "${TASK_PROMPT}" > "${_RAW_RESPONSE_FILE}"

) 200>"${REPO_ROOT}/.claude/agents/.lock" || _SUBSHELL_EXIT_CODE=$?

# The combined system-prompt temp file is no longer needed after the run.
rm -f "${_COMBINED_SYSPROMPT_FILE}"

if [[ $_SUBSHELL_EXIT_CODE -ne 0 ]]; then
    exit $_SUBSHELL_EXIT_CODE
fi

RAW_RESPONSE="$(cat "${_RAW_RESPONSE_FILE}")"
rm -f "${_RAW_RESPONSE_FILE}"

# ---------------------------------------------------------------------------
# Extract the result field from Claude Code's JSON envelope
# Claude Code --output-format json wraps the response in:
#   { "result": "<content>", "is_error": false, ... }
# ---------------------------------------------------------------------------
IS_ERROR="$(printf '%s' "$RAW_RESPONSE" | jq -r '.is_error // false')"

if [[ "$IS_ERROR" == "true" ]]; then
    echo "ERROR: Claude Code reported an error for stage '${STAGE}':" >&2
    printf '%s' "$RAW_RESPONSE" | jq -r '.result // .error // "unknown error"' >&2
    emit_event "stage_failed" ',"error_reason":"claude_code_error"'
    exit 2
fi

# Per the Claude Code headless docs: when --json-schema is used, the validated
# payload lives in `.structured_output`. The `.result` field is a plain-text
# summary intended for human display. We persist both: the structured payload
# is the artifact-of-record; the text summary is saved alongside as a brief.
STAGE_JSON="$(printf '%s' "$RAW_RESPONSE" | jq -c '.structured_output // empty')"

if [[ -z "$STAGE_JSON" || "$STAGE_JSON" == "null" ]]; then
    echo "ERROR: Stage '${STAGE}' did not emit a structured_output payload." >&2
    echo "       The CLI rejected the schema or the model produced no validated output." >&2
    echo "       Raw response (truncated):" >&2
    printf '%s' "$RAW_RESPONSE" | jq -r '.result // "(no result field)"' >&2 | head -c 2000
    emit_event "stage_failed" ',"error_reason":"no_structured_output"'
    exit 2
fi

# Pretty-print for the on-disk artifact
STAGE_JSON="$(printf '%s' "$STAGE_JSON" | jq .)"

# Capture the human-readable summary (.result) for the brief
RESULT_SUMMARY="$(printf '%s' "$RAW_RESPONSE" | jq -r '.result // ""')"

# ---------------------------------------------------------------------------
# Write validated JSON to disk (durable output before any further processing)
# ---------------------------------------------------------------------------
printf '%s\n' "$STAGE_JSON" > "$JSON_OUTPUT"
echo "Written: ${JSON_OUTPUT}"

# Save the model's plain-text summary alongside the JSON artifact (≤2KB)
SUMMARY_OUTPUT="${OUTPUT_DIR}/${ARTIFACT_BASE}_SUMMARY.txt"
printf '%s\n' "${RESULT_SUMMARY:0:2000}" > "$SUMMARY_OUTPUT"
echo "Written: ${SUMMARY_OUTPUT}"

# ---------------------------------------------------------------------------
# Stage summary severity affirmation check
# Skipped for: solutions, evaluator, cross-panel
# For requirements/attack-scenarios/risk-analysis: if max severity is critical
# or high, the stage_summary must affirmatively mention it (not negate it).
# ---------------------------------------------------------------------------
case "$STAGE" in
    solutions|evaluator|cross-panel)
        # Skip severity check for these stages
        ;;
    requirements|attack-scenarios|risk-analysis)
        # Determine the jq path to severity fields per stage
        _SEV_JQ_PATH=""
        case "$STAGE" in
            requirements)    _SEV_JQ_PATH='[.requirements[]?.severity // empty]' ;;
            attack-scenarios) _SEV_JQ_PATH='[.scenarios[]?.severity // empty]' ;;
            risk-analysis)   _SEV_JQ_PATH='[.risks[]?.overall_rating // empty]' ;;
        esac

        # Compute the max severity (critical > high > medium > low)
        _MAX_SEV="$(printf '%s' "$STAGE_JSON" | jq -r --arg path "$_SEV_JQ_PATH" '
            '"$_SEV_JQ_PATH"' |
            map(ascii_downcase) |
            if any(. == "critical") then "critical"
            elif any(. == "high") then "high"
            elif any(. == "medium") then "medium"
            elif any(. == "low") then "low"
            else "none"
            end
        ' 2>/dev/null || printf 'none')"

        if [[ "$_MAX_SEV" == "critical" || "$_MAX_SEV" == "high" ]]; then
            _STAGE_SUMMARY="$(printf '%s' "$STAGE_JSON" | jq -r '.stage_summary // ""' 2>/dev/null || true)"
            _SUMMARY_LOWER="$(printf '%s' "$_STAGE_SUMMARY" | tr '[:upper:]' '[:lower:]')"
            _SEV_CHECK_FAIL=0

            if [[ "$_MAX_SEV" == "critical" ]]; then
                # For requirements and risk-analysis: must mention 'critical' AND must not negate it.
                # For attack-scenarios: the summary describes attacker goals/chains, not defensive ratings
                # (a legitimate ARES summary may say "zero high-severity findings" as the attacker's
                # objective), so affirmative-presence is unsafe here — only the negation guard applies.
                # RESIDUAL (ATK-006 / CONFLICT-004): a past-tense framing such as "all findings represent
                # low-severity drift" evades the negation guard. Accepted; structural fix requires a
                # machine-readable severity field on the artifact rather than prose matching.
                if [[ "$STAGE" != "attack-scenarios" ]]; then
                    if ! printf '%s' "$_SUMMARY_LOWER" | grep -qiE 'critical'; then
                        _SEV_CHECK_FAIL=1
                        echo "ERROR: stage_summary_severity_mismatch: max severity is 'critical' but stage_summary does not mention 'critical'" >&2
                    fi
                fi
                # Negation guard applies to all stages
                if [[ $_SEV_CHECK_FAIL -eq 0 ]]; then
                    if printf '%s' "$_SUMMARY_LOWER" | grep -qiE 'no critical|zero critical|no high or critical|no critical findings|no critical issues'; then
                        _SEV_CHECK_FAIL=1
                        echo "ERROR: stage_summary_severity_mismatch: stage_summary negates critical severity (contains negation phrase)" >&2
                    fi
                fi
            elif [[ "$_MAX_SEV" == "high" ]]; then
                # Must contain 'high' as a whole word or in 'high-severity'
                if ! printf '%s' "$_SUMMARY_LOWER" | grep -qiE '\bhigh\b|high-severity'; then
                    _SEV_CHECK_FAIL=1
                    echo "ERROR: stage_summary_severity_mismatch: max severity is 'high' but stage_summary does not mention 'high'" >&2
                fi
            fi

            if [[ $_SEV_CHECK_FAIL -ne 0 ]]; then
                # Write rejected artifact as sidecar for forensics
                _REJECTED_OUTPUT="${OUTPUT_DIR}/${ARTIFACT_BASE}.rejected.json"
                cp "$JSON_OUTPUT" "$_REJECTED_OUTPUT" 2>/dev/null || true
                echo "Written (rejected sidecar): ${_REJECTED_OUTPUT}" >&2
                emit_event "stage_failed" ',"error_reason":"stage_summary_severity_mismatch"'
                exit 2
            fi
        fi
        ;;
esac

# ---------------------------------------------------------------------------
# Evaluator PASS-gate grounding (deterministic verdict floor)
# ---------------------------------------------------------------------------
# The evaluator's PASS rule (critical==0 && high==0 && coverage>=0.8) is a
# published, gameable metric: a reward-hacking or anchored grader can self-report
# inflated coverage, or rubber-stamp PASS while its own findings say otherwise
# (Mythos card §4.4.2 / §2.3.3.1 — faking compliance markers, padding to clear a
# binary threshold). check_evaluator_verdict.sh recomputes the coverage floor
# DETERMINISTICALLY from the actual artifacts and fails (exit 2) only when a PASS
# verdict is contradicted by that floor. The check is asymmetric — a NEEDS_WORK
# verdict is never blocked. See that script's header for the full contract.
if [[ "$STAGE" == "evaluator" ]]; then
    _GATE_RC=0
    "${SCRIPT_DIR}/check_evaluator_verdict.sh" "${OUTPUT_DIR}" || _GATE_RC=$?
    if [[ $_GATE_RC -ne 0 ]]; then
        _REJECTED_OUTPUT="${OUTPUT_DIR}/${ARTIFACT_BASE}.rejected.json"
        cp "$JSON_OUTPUT" "$_REJECTED_OUTPUT" 2>/dev/null || true
        echo "Written (rejected sidecar): ${_REJECTED_OUTPUT}" >&2
        if [[ $_GATE_RC -eq 2 ]]; then
            emit_event "stage_failed" ',"error_reason":"evaluator_verdict_unsupported"'
        else
            emit_event "stage_failed" ',"error_reason":"evaluator_verdict_check_error"'
        fi
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# Render markdown from JSON
# ---------------------------------------------------------------------------
"${SCRIPT_DIR}/render_markdown.sh" "${STAGE}" "${JSON_OUTPUT}" > "${MD_OUTPUT}"
echo "Written: ${MD_OUTPUT}"

emit_event "stage_completed" ",\"artifact_path\":\"${JSON_OUTPUT//\"/\\\"}\""
echo "Stage '${STAGE}' complete."
exit 0
