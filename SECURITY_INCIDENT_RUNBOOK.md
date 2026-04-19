# Security Incident Response Runbook

**Classification**: INTERNAL — SECURITY SENSITIVE
**Last Updated**: 2026-04-19
**Owner**: Security Team

---

## Activation Criteria

Activate this runbook when:
- An agent is confirmed compromised (malicious behavior, unexpected tool usage)
- An agent is confirmed exfiltrating data or modifying files outside its scope
- A model server has been identified as attacker-controlled
- Unauthorized access to agent configurations detected

---

## Kill Switch Procedure (< 60 seconds to full termination)

### Phase 1: Immediate Session Termination (0-15 seconds)

```bash
# 1. Kill all running Ollama processes
pkill -9 -f "ollama" && echo "Ollama processes killed" || echo "No ollama processes found"

# 2. Verify no ollama processes remain
ps aux | grep ollama | grep -v grep || echo "Verified: no ollama processes"

# 3. Kill any hanging agent sessions
pkill -9 -f "claude" && echo "Claude processes killed" || echo "No claude processes found"

# 4. If running via systemd service
sudo systemctl stop ollama.service 2>/dev/null || true
sudo systemctl disable ollama.service 2>/dev/null || true
```

### Phase 2: Model Access Revocation (15-30 seconds)

```bash
# 5. Revoke any API keys used by agents (example — adjust for your setup)
unset OLLAMA_API_KEY 2>/dev/null || true
unset OLLAMA_ORG_KEY 2>/dev/null || true

# 6. If using API key files
chmod 000 ~/.ollama/api_key 2>/dev/null || true

# 7. Remove any cached credentials
rm -f ~/.ollama/credentials 2>/dev/null || true
```

### Phase 3: Evidence Preservation (30-45 seconds)

```bash
# 8. Preserve evidence before any cleanup
tar -czf /tmp/agent-config-snapshot-$(date +%Y%m%d-%H%M%S).tar.gz \
    /home/cmc/git/claude/.claude/ 2>/dev/null || true

# Snapshot running processes
ps aux > /tmp/process-snapshot-$(date +%Y%m%d-%H%M%S).log

# Snapshot network connections
ss -tulpn > /tmp/network-snapshot-$(date +%Y%m%d-%H%M%S).log
```

### Phase 4: Notification (45-60 seconds)

```bash
# 9. Notify security team
# Adjust contact method for your environment
echo "Agent kill switch activated at $(date). All sessions terminated." | mail -s "SECURITY INCIDENT" root 2>/dev/null || true

# 10. Create incident ticket (adjust for your ticketing system)
echo "SECURITY INCIDENT: Agent compromise detected. Kill switch activated at $(date)" >> /tmp/incident-log.txt
```

---

## Recovery Procedure

### Prerequisites Before Recovery
1. Root cause analysis complete
2. Attack vector identified and remediated
3. All affected systems patched/verified

### Recovery Steps

```bash
# 1. Re-enable ollama service
sudo systemctl enable ollama.service 2>/dev/null || true
sudo systemctl start ollama.service 2>/dev/null || true

# 2. Verify git repository integrity
cd /home/cmc/git/claude
git status
git log --oneline -5

# 3. Run agent hash verification
./verify-all-agents.sh

# 4. Run model digest verification
./verify-model-digest.sh <each-approved-model>

# 5. Restore any modified files from git
git checkout -- .

# 6. Resume agent sessions only after full security review
```

---

## Post-Incident

- Conduct full retrospective within 48 hours
- Update this runbook with lessons learned
- Review all agent logs for scope of compromise
- Rotate all credentials regardless of evidence of compromise
- Update threat model based on attack vector

---

## Quick Reference

```bash
# Emergency termination (single command)
pkill -9 -f "ollama" && pkill -9 -f "claude" && echo "All agent processes killed"

# Verify isolation
ps aux | grep -E "ollama|claude" | grep -v grep || echo "Verified isolated"
```
