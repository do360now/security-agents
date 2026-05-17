#!/usr/bin/env bash
# panel/wake.sh — Inspect a panel's event log and recommend the next stage to run.
#
# Usage: panel/wake.sh <output_dir>
#
# Exit codes:
#   0 = next stage identified, command printed to stdout
#   1 = panel complete (all 4 stages have stage_completed events)
#   2 = no events.jsonl (nothing to resume)
#   3 = malformed events log

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: panel/wake.sh <output_dir>" >&2
    exit 2
fi

OUTPUT_DIR="$1"
EVENT_LOG="${OUTPUT_DIR%/}/events.jsonl"

if [[ ! -f "$EVENT_LOG" ]]; then
    echo "No event log at $EVENT_LOG — nothing to resume." >&2
    exit 2
fi

# Detect mode: if any event names attack-scenarios, this is the offensive panel.
if grep -q '"stage":"attack-scenarios"' "$EVENT_LOG"; then
    SEQUENCE=(attack-scenarios risk-analysis solutions evaluator)
    MODE="offensive"
else
    SEQUENCE=(requirements risk-analysis solutions evaluator)
    MODE="defensive"
fi

# Resume point: first stage in the sequence with no stage_completed event.
# Use jq (required by run_stage.sh) for reliable per-field matching.
NEXT_STAGE=""
for stage in "${SEQUENCE[@]}"; do
    found="$(jq -r --arg s "$stage" 'select(.event_type=="stage_completed" and .stage==$s) | .id' "$EVENT_LOG" 2>/dev/null | head -1)"
    if [[ -z "$found" ]]; then
        NEXT_STAGE="$stage"
        break
    fi
done

if [[ -z "$NEXT_STAGE" ]]; then
    echo "Panel complete: all 4 ${MODE} stages have stage_completed events in $EVENT_LOG" >&2
    exit 1
fi

# Print the recommended command. Operator decides whether to run it.
cat <<INFO
Mode:           $MODE
Output dir:     $OUTPUT_DIR
Next stage:     $NEXT_STAGE
Event log:      $EVENT_LOG

Recommended command (review and run manually):

    panel/run_stage.sh $NEXT_STAGE "$OUTPUT_DIR" "<your task prompt for ${NEXT_STAGE}>"

INFO
exit 0
