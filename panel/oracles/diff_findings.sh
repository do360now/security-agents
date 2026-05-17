#!/usr/bin/env bash
# panel/oracles/diff_findings.sh — Compute the disagreement set between
# Claude's RISK_ANALYSIS.json and the SEMGREP_BASELINE.json oracle.
#
# Usage: panel/oracles/diff_findings.sh <output_dir>
#
# Writes <output_dir>/ORACLE_DIFF.json with three arrays:
#   semgrep_only — SAST findings whose file is not referenced by any Claude RISK
#   claude_only  — Claude RISKs whose target_component does not substring-match any SAST file
#   both         — overlap (heuristic file-path substring match)
#
# Exit codes:
#   0 = diff written
#   1 = argument or input error

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: panel/oracles/diff_findings.sh <output_dir>" >&2
    exit 1
fi

OUTPUT_DIR="$1"
RISK_FILE="${OUTPUT_DIR}/RISK_ANALYSIS.json"
BASELINE_FILE="${OUTPUT_DIR}/SEMGREP_BASELINE.json"
DIFF_FILE="${OUTPUT_DIR}/ORACLE_DIFF.json"

if [[ ! -f "$RISK_FILE" ]]; then
    echo "ERROR: RISK_ANALYSIS.json not found at $RISK_FILE" >&2
    exit 1
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "ERROR: SEMGREP_BASELINE.json not found at $BASELINE_FILE" >&2
    exit 1
fi

oracle_available="$(jq -r '.oracle_available' "$BASELINE_FILE")"

if [[ "$oracle_available" != "true" ]]; then
    cat > "$DIFF_FILE" <<EOF
{
  "oracle_available": false,
  "reason": "semgrep was not available when the baseline was produced",
  "summary": { "semgrep_only": 0, "claude_only": 0, "both": 0 },
  "semgrep_only": [],
  "claude_only": [],
  "both": []
}
EOF
    echo "Oracle unavailable — wrote stub diff to $DIFF_FILE" >&2
    exit 0
fi

# Heuristic match: a Claude RISK and a SAST finding "overlap" if the SAST
# finding's file appears as a substring of the Claude RISK's target_component.
# (Operator uses this as a starting point, not a strict mapping.)
jq --slurpfile risk "$RISK_FILE" '
  . as $baseline |
  ($risk[0].risks // []) as $claude_risks |
  ($baseline.findings // []) as $sast |

  # For each SAST finding, find Claude RISKs whose target_component contains its file
  ($sast | map(
    . as $f |
    . + {
      _matched_claude_ids: [
        $claude_risks[]
        | select(.target_component | tostring | contains($f.file))
        | .id
      ]
    }
  )) as $sast_annotated |

  # For each Claude RISK, find SAST findings whose file is in target_component
  ($claude_risks | map(
    . as $r |
    . + {
      _matched_sast_ids: [
        $sast[]
        | . as $f
        | select($r.target_component | tostring | contains($f.file))
        | $f.id
      ]
    }
  )) as $risk_annotated |

  {
    oracle_available: true,
    summary: {
      semgrep_only: ($sast_annotated | map(select(._matched_claude_ids | length == 0)) | length),
      claude_only:  ($risk_annotated | map(select(._matched_sast_ids   | length == 0)) | length),
      both:         ($sast_annotated | map(select(._matched_claude_ids | length > 0))  | length)
    },
    semgrep_only: ($sast_annotated | map(select(._matched_claude_ids | length == 0) | del(._matched_claude_ids))),
    claude_only:  ($risk_annotated | map(select(._matched_sast_ids   | length == 0) | del(._matched_sast_ids))),
    both: [
      $sast_annotated[]
      | select(._matched_claude_ids | length > 0)
      | { sast_id: .id, sast_file: .file, claude_risk_ids: ._matched_claude_ids }
    ]
  }
' "$BASELINE_FILE" > "$DIFF_FILE"

so="$(jq '.summary.semgrep_only' "$DIFF_FILE")"
co="$(jq '.summary.claude_only' "$DIFF_FILE")"
b="$(jq '.summary.both' "$DIFF_FILE")"
echo "Wrote diff: semgrep_only=$so claude_only=$co both=$b → $DIFF_FILE" >&2
exit 0
