#!/usr/bin/env bash
# agent-logger.sh — Log agent commands to audit trail
# Usage (source for functions):
#   source ./agent-logger.sh
#   log_tool_invocation "security-agent" "Bash" '{"command":"ps aux"}'
#
# CLI mode (wrap a command):
#   ./agent-logger.sh <agent-id> <command...>

set -euo pipefail

LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-audit}"
LOG_FILE="${AGENT_LOG_FILE:-$LOG_DIR/audit.jsonl}"
SESSION_ID="${AGENT_SESSION_ID:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)}"

# Ensure log directory exists
ensure_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || return 1
        chmod 755 "$LOG_DIR"
    fi
}

# Write a JSON entry to the log file
log_write() {
    local json="$1"
    if [[ -d "$LOG_DIR" ]]; then
        printf '%s\n' "$json" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Build a JSON entry via python3 (safe string handling)
build_json() {
    local type="$1"; shift
    local agent_id="$1"; shift
    python3 - "$type" "$agent_id" "$SESSION_ID" "$@" <<'PYEOF'
import sys, json

type_ = sys.argv[1]
agent_id = sys.argv[2]
session = sys.argv[3]
extra = sys.argv[4:]

d = {
    "timestamp": __import__("datetime").datetime.utcnow().isoformat() + "Z",
    "type": type_,
    "agent_id": agent_id,
    "session_id": session,
}
# Add extra key=value pairs
for item in extra:
    if "=" in item:
        k, v = item.split("=", 1)
        try:
            d[k] = json.loads(v) if v.startswith("{") else v
        except Exception:
            d[k] = v
print(json.dumps(d))
PYEOF
}

# Log a tool invocation
log_tool_invocation() {
    local agent_id="$1"; shift
    local tool="$1"; shift
    local params="${1:-}"
    local entry
    entry=$(build_json "tool_invocation" "$agent_id" "tool=$tool" "params=$params")
    log_write "$entry"
}

# Log an advisor call input
log_advisor_input() {
    local agent_id="$1"; shift
    local advisor="$1"; shift
    local tokens="${1:-0}"
    local entry
    entry=$(build_json "advisor_call_input" "$agent_id" "advisor=$advisor" "input_tokens=$tokens")
    log_write "$entry"
}

# Log an advisor response
log_advisor_response() {
    local agent_id="$1"; shift
    local advisor="$1"; shift
    local tokens="${1:-0}"
    local preview="${1:-}"
    preview="${preview:0:500}"
    local entry
    entry=$(build_json "advisor_call_output" "$agent_id" "advisor=$advisor" "output_tokens=$tokens" "response_preview=$preview")
    log_write "$entry"
}

# Log a file access event
log_file_access() {
    local agent_id="$1"; shift
    local path="$1"; shift
    local operation="$1"
    local entry
    entry=$(build_json "file_access" "$agent_id" "path=$path" "operation=$operation")
    log_write "$entry"
}

# Log an anomaly alert
log_anomaly() {
    local agent_id="$1"; shift
    local anomaly_type="$1"; shift
    local tool="$1"; shift
    local expected_scope="$1"; shift
    local severity="${1:-medium}"
    local entry
    entry=$(build_json "anomaly_alert" "$agent_id" "anomaly_type=$anomaly_type" "tool=$tool" "expected_scope=$expected_scope" "severity=$severity")
    log_write "$entry"
    echo "ALERT: [$agent_id] $anomaly_type — tool=$tool severity=$severity" >&2
}

# --- CLI mode ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$#" -lt 2 ]]; then
        echo "Usage: $0 <agent-id> <command...>" >&2
        echo "   or: source $0 && log_tool_invocation ..." >&2
        exit 1
    fi

    AGENT_ID="$1"; shift
    COMMAND="$*"
    CWD=$(python3 -c "import os,json; print(json.dumps(os.getcwd()))")
    PARAMS=$(python3 -c "import os,json; print(json.dumps({'command':'$COMMAND','cwd':$CWD}))")

    ensure_log_dir
    log_tool_invocation "$AGENT_ID" "ollama" "$PARAMS"
    eval "$COMMAND"
fi
