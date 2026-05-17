#!/usr/bin/env bash
# panel/oracles/semgrep_baseline.sh — Run Semgrep against a target codebase and
# produce a normalized SAST baseline. If semgrep is not installed, write a
# no-op baseline so downstream tools (diff_findings.sh) can still run.
#
# Usage: panel/oracles/semgrep_baseline.sh <target_dir> <output_dir>
#
# Exit codes:
#   0 = baseline written (with oracle_available true or false)
#   1 = argument or path error
#   2 = semgrep failed unexpectedly

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: panel/oracles/semgrep_baseline.sh <target_dir> <output_dir>" >&2
    exit 1
fi

TARGET_DIR="$1"
OUTPUT_DIR="$2"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: target dir not found: $TARGET_DIR" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
BASELINE="${OUTPUT_DIR}/SEMGREP_BASELINE.json"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Graceful no-op when semgrep is not installed
if ! command -v semgrep >/dev/null 2>&1; then
    cat > "$BASELINE" <<EOF
{
  "oracle_available": false,
  "tool": "semgrep",
  "reason": "semgrep not installed (run: pipx install semgrep)",
  "target": "$TARGET_DIR",
  "scan_timestamp": "$ts",
  "findings": []
}
EOF
    echo "semgrep not installed — wrote no-op baseline to $BASELINE" >&2
    exit 0
fi

# semgrep is available — run the scan
VERSION="$(semgrep --version 2>/dev/null || echo unknown)"
RAW_JSON="$(mktemp)"
trap 'rm -f "$RAW_JSON"' EXIT

if ! semgrep --config auto --json --quiet "$TARGET_DIR" > "$RAW_JSON" 2>/dev/null; then
    echo "ERROR: semgrep run failed for $TARGET_DIR" >&2
    exit 2
fi

# Normalize findings via jq into the documented schema
# Severity map: ERROR -> high, WARNING -> medium, INFO -> low (else medium)
jq --arg target "$TARGET_DIR" --arg ts "$ts" --arg ver "$VERSION" '
{
  oracle_available: true,
  tool: "semgrep",
  version: $ver,
  target: $target,
  scan_timestamp: $ts,
  findings: [
    (.results // []) | to_entries[] | {
      id: ("SAST-" + (1000 + .key | tostring | .[1:])),
      rule_id: .value.check_id,
      severity: (
        .value.extra.severity
        | if . == "ERROR" then "high"
          elif . == "WARNING" then "medium"
          elif . == "INFO" then "low"
          else "medium" end
      ),
      file: .value.path,
      line: (.value.start.line // 0),
      message: (.value.extra.message // ""),
      cwe: ((.value.extra.metadata.cwe // []) | if type == "string" then [.] else . end)
    }
  ]
}
' "$RAW_JSON" > "$BASELINE"

count="$(jq '.findings | length' "$BASELINE")"
echo "Wrote $count SAST findings to $BASELINE" >&2
exit 0
