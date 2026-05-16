# Security Incident Response Runbook

**Classification**: INTERNAL — SECURITY SENSITIVE
**Last Updated**: 2026-04-24
**Owner**: Security Team

---

## Activation Criteria

Activate this runbook when:
- An agent is confirmed compromised (malicious behavior, unexpected tool usage)
- An agent is confirmed exfiltrating data or modifying files outside its scope
- A Claude API credential has been identified as leaked or attacker-controlled
- Unauthorized access to agent configurations detected

---

## Kill Switch Procedure (< 60 seconds to full termination)

### Phase 1: Immediate Session Termination (0-15 seconds)

```bash
# 1. Kill all running Claude Code processes (interactive sessions and `claude -p` advisor calls)
pkill -9 -f "claude" && echo "Claude processes killed" || echo "No claude processes found"

# 2. Verify no claude processes remain
ps aux | grep -E "(^|[^a-z])claude" | grep -v grep || echo "Verified: no claude processes"

# 3. Kill any hanging Node subprocesses spawned by agents
pkill -9 -f "node.*claude" 2>/dev/null || true
```

### Phase 2: API Credential Revocation (15-30 seconds)

```bash
# 4. Revoke the Anthropic API key from the current shell
unset ANTHROPIC_API_KEY 2>/dev/null || true
unset ANTHROPIC_AUTH_TOKEN 2>/dev/null || true

# 5. Remove cached Claude Code credentials
rm -f ~/.claude/.credentials.json 2>/dev/null || true
rm -rf ~/.claude/auth 2>/dev/null || true

# 6. Rotate the API key in the Anthropic Console (https://console.anthropic.com/settings/keys)
#    — revoke the current key and issue a new one before resuming any agent work.
echo "Rotate API key at: https://console.anthropic.com/settings/keys"

# 7. Check for billing/usage anomalies — hosted API threat model differs from local:
#    a compromised key can drive up charges faster than local compromise could
#    exhaust compute. Review recent usage before the key rotation window closes.
echo "Check usage anomalies at: https://console.anthropic.com/settings/usage"
```

### Phase 3: Evidence Preservation (30-45 seconds)

```bash
# 7. Preserve evidence before any cleanup
tar -czf /tmp/agent-config-snapshot-$(date +%Y%m%d-%H%M%S).tar.gz \
    /home/cmc/git/security-agents/.claude/ 2>/dev/null || true

# Snapshot running processes
ps aux > /tmp/process-snapshot-$(date +%Y%m%d-%H%M%S).log

# Snapshot network connections
ss -tulpn > /tmp/network-snapshot-$(date +%Y%m%d-%H%M%S).log

# Snapshot Claude Code session transcripts (if present)
cp -r ~/.claude/projects /tmp/claude-sessions-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
```

### Phase 4: Notification (45-60 seconds)

```bash
# 8. Notify security team
# Adjust contact method for your environment
echo "Agent kill switch activated at $(date). All sessions terminated." | mail -s "SECURITY INCIDENT" root 2>/dev/null || true

# 9. Create incident ticket (adjust for your ticketing system)
echo "SECURITY INCIDENT: Agent compromise detected. Kill switch activated at $(date)" >> /tmp/incident-log.txt
```

---

## Recovery Procedure

### Prerequisites Before Recovery
1. Root cause analysis complete
2. Attack vector identified and remediated
3. Anthropic API key rotated
4. All affected systems patched/verified

### Recovery Steps

```bash
# 1. Verify git repository integrity
cd /home/cmc/git/security-agents
git status
git log --oneline -5

# 2. Run agent hash verification
./verify-all-agents.sh

# 3. Verify each allowlisted Claude model ID resolves against the allowlist
for model in claude-opus-4-7 claude-opus-4-6 claude-sonnet-4-6 claude-haiku-4-5; do
    ./verify-model-digest.sh "$model"
done

# 4. Restore any modified files from git
git checkout -- .

# 5. Re-authenticate Claude Code with the rotated API key
#    (interactive): run `claude` and follow the login prompt, OR
#    (non-interactive): export ANTHROPIC_API_KEY=<new-key>
echo "Re-auth via: claude  # then /login"

# 6. Resume agent sessions only after full security review
```

---

## Audit Logging Infrastructure

**AGENT_LOGGING_SCHEMA**: All agent sessions log to `/tmp/ai-security-panel/session-log.jsonl` with the following fields:
- `timestamp` (ISO 8601)
- `agent` (name from frontmatter)
- `action` (tool invoked)
- `target` (file/path/endpoint)
- `advisorCalled` (boolean)
- `advisorModel` (Claude model ID, e.g. `claude-opus-4-7`)
- `validationPassed` (boolean — for advisor outputs)

Session logs are rotation-limited to 100MB max; older logs are archived to `/tmp/ai-security-panel/archive/`.

**Audit Log Retention**: 90 days minimum for compliance with EU AI Act (Aug 2026) and NIST AI RMF adversarial testing requirements.

Claude Code itself maintains session transcripts under `~/.claude/projects/<project>/` — these are an additional source of ground-truth audit evidence and should be preserved during incident response (see Phase 3 above).

---

## Post-Incident Actions

- Conduct full retrospective within 48 hours
- Update this runbook with lessons learned
- Review all agent logs for scope of compromise
- Rotate API credentials (Anthropic console) regardless of evidence of compromise
- Update threat model based on attack vector
- Run adversarial/red-team tests (`make red-team-full`) to confirm mitigations hold

---

## Quick Reference

```bash
# Emergency termination (single command)
pkill -9 -f "claude" && echo "All Claude agent processes killed"

# Verify isolation
ps aux | grep -E "(^|[^a-z])claude" | grep -v grep || echo "Verified isolated"
```

---

## Preemptive Kill-Switch Hook

`.claude/hooks/kill-switch.sh` is wired as a `PreToolUse` hook via `.claude/settings.json`. It runs before every tool call in every agent session. If the file `AGENT_STOP` exists in the project root, the hook blocks the tool call with `exit 2` and prints the file's contents as the reason. If the file is empty, a default message is emitted.

This is a preemptive control: it stops new actions from being started, as opposed to `pkill` alone, which kills mid-flight processes but cannot prevent the next tool call from being dispatched before the signal lands.

**Blocking a running session (operator usage):**

```bash
# Block all subsequent tool calls — optionally record the reason
echo "Suspected prompt injection in risk-analysis run" > AGENT_STOP

# Combined fast-kill (recommended): blocks new actions AND kills running ones
touch AGENT_STOP && pkill -9 -f claude
```

**Recovery — remove the stop file once the incident is contained:**

```bash
rm AGENT_STOP
```

The hook reads `$CLAUDE_PROJECT_DIR` (injected by Claude Code at runtime). If that variable is unset (e.g., direct shell testing), it falls back to two levels above the script's own directory.
