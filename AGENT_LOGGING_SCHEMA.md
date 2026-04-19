# Agent Audit Log Schema

**Format**: JSON Lines (one JSON object per line)
**Destination**: `/var/log/agent-audit/audit.jsonl` (or cloud log sink)
**Retention**: 90 days minimum
**Rotation**: Daily, or when file reaches 100MB
**Immutability**: `chattr +a audit.jsonl` (append-only — requires root)

---

## Log Entry Types

### Tool Invocation
```json
{
  "timestamp": "2026-04-19T14:32:01.123Z",
  "type": "tool_invocation",
  "agent_id": "security-panel",
  "tool": "Bash",
  "params": {
    "command": "ollama run devstral-2:123b-cloud ...",
    "cwd": "/home/cmc/git/claude"
  },
  "session_id": "sess-abc123",
  "executor": "devstral-2:123b-cloud"
}
```

### Advisor Call (Input — sanitized before logging)
```json
{
  "timestamp": "2026-04-19T14:32:05.456Z",
  "type": "advisor_call_input",
  "agent_id": "security-agent",
  "advisor": "glm-5.1:cloud",
  "input_tokens": 1234,
  "session_id": "sess-abc123"
}
```

### Advisor Response
```json
{
  "timestamp": "2026-04-19T14:32:08.789Z",
  "type": "advisor_call_output",
  "agent_id": "security-agent",
  "advisor": "glm-5.1:cloud",
  "output_tokens": 89,
  "response_preview": "Enumerated steps for..."
}
```

### File Access
```json
{
  "timestamp": "2026-04-19T14:32:10.001Z",
  "type": "file_access",
  "agent_id": "security-agent",
  "path": "/home/cmc/git/claude/.claude/agents/security-panel.md",
  "operation": "read",
  "session_id": "sess-abc123"
}
```

### Anomaly Alert
```json
{
  "timestamp": "2026-04-19T14:32:15.123Z",
  "type": "anomaly_alert",
  "agent_id": "security-agent",
  "anomaly_type": "out_of_scope_tool",
  "tool": "Write",
  "expected_scope": ["Read", "Grep"],
  "severity": "high"
}
```

---

## LogSanitizer (apply before logging advisor I/O)

```python
def sanitize_for_logging(text, max_length=500):
    """Remove sensitive data before logging advisor I/O."""
    import re
    # Truncate long outputs
    text = text[:max_length] + "..." if len(text) > max_length else text
    # Redact potential secrets (API keys, tokens)
    text = re.sub(
        r'(api[_-]?key["\']?\s*[:=]\s*)["\']?[\w-]{8,}["\']?',
        r'\1[REDACTED]',
        text,
        flags=re.I
    )
    return text
```

---

## Log Destination

- **Preferred**: Cloud log sink (S3 + CloudWatch, GCP Logging, Azure Monitor)
- **Fallback**: Local append-only file: `/var/log/agent-audit/audit.jsonl`
- **Setup**:
  ```bash
  sudo mkdir -p /var/log/agent-audit
  sudo chmod 755 /var/log/agent-audit
  sudo touch /var/log/agent-audit/audit.jsonl
  sudo chmod 644 /var/log/agent-audit/audit.jsonl
  sudo chattr +a /var/log/agent-audit/audit.jsonl 2>/dev/null || echo "Note: chattr requires root + ext4/xfs"
  ```

---

## Retention Policy

- **Minimum**: 90 days
- **Rotation**: Daily at midnight UTC, or when file exceeds 100MB
- **Archive**: Rotated files archived to `/var/log/agent-audit/archive/` with gzip compression
- **Deletion**: Files older than 90 days auto-deleted by logrotate cron job

### logrotate config: `/etc/logrotate.d/agent-audit`
```
/var/log/agent-audit/audit.jsonl {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    size 100M
    postrotate
        chattr +a /var/log/agent-audit/audit.jsonl 2>/dev/null || true
    endscript
}
```

---

## What This Does NOT Protect Against

- A compromised agent that can write to the log file and tamper with entries (relies on append-only enforcement + git signing)
- An attacker who clears logs before exfiltrating (append-only prevents deletion but not overwrite by root)
- A full host compromise where the attacker controls log infrastructure
