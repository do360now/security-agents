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
#              --model claude-sonnet-4-6 \
#              "<task_prompt>"
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
case "$STAGE" in
    attack-scenarios)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/attack-scenarios.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/attack-scenarios.md"
        ARTIFACT_BASE="ATTACK_SCENARIOS"
        # ARES may fetch CVE / threat intel context
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob,WebFetch"
        ;;
    requirements)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/requirements.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/requirements.md"
        ARTIFACT_BASE="REQUIREMENTS"
        # requirements may benefit from WebFetch for CVE lookups
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob,WebFetch"
        ;;
    risk-analysis)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/risk-analysis.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/risk-analysis.md"
        ARTIFACT_BASE="RISK_ANALYSIS"
        # risk-analysis reads local files only; no web tools needed
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob"
        ;;
    solutions)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/solutions.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/solutions.md"
        ARTIFACT_BASE="SOLUTIONS"
        # solutions reads local files only; no web tools needed
        ALLOWED_TOOLS="Read,Write,Bash,Grep,Glob"
        ;;
    evaluator)
        SCHEMA_FILE="${REPO_ROOT}/panel/schemas/evaluator.schema.json"
        SYSPROMPT_FILE="${REPO_ROOT}/panel/system-prompts/evaluator.md"
        ARTIFACT_BASE="EVALUATION"
        # evaluator reads only — no Write, no WebFetch
        ALLOWED_TOOLS="Read,Bash,Grep,Glob"
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
# Build and run the claude -p invocation
# ---------------------------------------------------------------------------
SCHEMA_CONTENT="$(cat "${SCHEMA_FILE}")"

RAW_RESPONSE="$(claude -p \
    --append-system-prompt-file "${SYSPROMPT_FILE}" \
    --output-format json \
    --json-schema "${SCHEMA_CONTENT}" \
    --allowedTools "${ALLOWED_TOOLS}" \
    --model claude-sonnet-4-6 \
    "${TASK_PROMPT}")"

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
# Render markdown from JSON
# ---------------------------------------------------------------------------
"${SCRIPT_DIR}/render_markdown.sh" "${STAGE}" "${JSON_OUTPUT}" > "${MD_OUTPUT}"
echo "Written: ${MD_OUTPUT}"

emit_event "stage_completed" ",\"artifact_path\":\"${JSON_OUTPUT//\"/\\\"}\""
echo "Stage '${STAGE}' complete."
exit 0
