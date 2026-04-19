# How to Respond to a Security Incident

Kill switch procedure — full termination in under 60 seconds.

---

## Immediate Actions (< 60 seconds)

### Phase 1: Terminate Sessions (0–15s)

```bash
# Kill all Ollama processes
pkill -9 -f "ollama" && echo "Ollama processes killed" || echo "No ollama processes found"

# Verify no ollama processes remain
ps aux | grep ollama | grep -v grep || echo "Verified: no ollama processes"

# Kill Claude processes
pkill -9 -f "claude" && echo "Claude processes killed" || echo "No claude processes found"

# If running via systemd
sudo systemctl stop ollama.service 2>/dev/null || true
sudo systemctl disable ollama.service 2>/dev/null || true
```

### Phase 2: Revoke Access (15–30s)

```bash
# Unset API keys
unset OLLAMA_API_KEY 2>/dev/null || true
unset OLLAMA_ORG_KEY 2>/dev/null || true

# Revoke cached credentials
chmod 000 ~/.ollama/api_key 2>/dev/null || true
rm -f ~/.ollama/credentials 2>/dev/null || true
```

### Phase 3: Preserve Evidence (30–45s)

```bash
# Snapshot agent configs
tar -czf /tmp/agent-config-snapshot-$(date +%Y%m%d-%H%M%S).tar.gz \
    .claude/ 2>/dev/null || true

# Snapshot running processes
ps aux > /tmp/process-snapshot-$(date +%Y%m%d-%H%M%S).log

# Snapshot network connections
ss -tulpn > /tmp/network-snapshot-$(date +%Y%m%d-%H%M%S).log
```

### Phase 4: Notify (45–60s)

```bash
# Create incident record
echo "SECURITY INCIDENT: Kill switch activated at $(date)" >> /tmp/incident-log.txt

# Notify team (adjust for your setup)
mail -s "SECURITY INCIDENT" security-team@example.com < /tmp/incident-log.txt
```

---

## Single-Command Emergency Termination

```bash
pkill -9 -f "ollama" && pkill -9 -f "claude" && echo "All agent processes killed"
```

Verify isolation:

```bash
ps aux | grep -E "ollama|claude" | grep -v grep || echo "Verified isolated"
```

---

## Recovery

After the situation is contained:

1. Analyze audit logs (`/var/log/agent-audit/audit.jsonl`) for scope of compromise
2. Run `git status` and `git log --oneline -5` to check for unauthorized changes
3. Run `./verify-all-agents.sh` to verify no frontmatter hashes were tampered with
4. Restore any modified files: `git checkout -- .`
5. Review with team before resuming operations

---

## See Also

- [SECURITY_INCIDENT_RUNBOOK.md](../SECURITY_INCIDENT_RUNBOOK.md) — Full runbook with all commands
- [Reference: Verification scripts](../reference/) — Scripts to check system integrity
