# Reference — Command Reference

All shell commands in the repository.

## Setup and Testing

```bash
# Clone the repository
git clone https://github.com/do360now/security-agents.git
cd security-agents

# Make scripts executable
chmod +x setup-and-redteam.sh *.sh

# Run full test suite
./setup-and-redteam.sh

# Run tests via Makefile
make red-team-test      # Quick summary
make red-team-full     # Verbose output
```

## Verification Scripts

```bash
./verify-all-agents.sh                    # Agent frontmatter hashes
./verify-model-digest.sh <model>:cloud   # Model digest vs allowlist
./verify-skill-versions.sh               # Skill version pinning
./validate-makefile-models.sh            # Makefile model names
./validate-advisor-output.sh < file.txt   # Advisor output contract
./detect-config-drift.sh                 # Git diff for config changes
./pre-commit-inline-script-check.sh      # Dangerous command substitutions
```

## Agent Invocation

```bash
# Via Agent tool (Claude Code)
Agent(subagent_type="security-panel", prompt="[threat or system description]")
Agent(subagent_type="security-agent", prompt="[task description]")
Agent(subagent_type="system-health-agent", prompt="[task description]")
Agent(subagent_type="maintenance-agent", prompt="[task description]")
```

## Ollama Commands

```bash
# List available models
ollama list

# Show model info (digest, size, etc.)
ollama show <model>:cloud

# Launch Claude Code with a specific model
ollama launch claude --model <model>:cloud

# Via Makefile
make start-minimax    # Launch with minimax-m2.5:cloud
make start-minimax2.7 # Launch with minimax-m2.7:cloud
```

## Audit Logging

```bash
# Log directory (requires root to create)
sudo mkdir -p /var/log/agent-audit

# Wrap a command with logging
./agent-logger.sh <agent-id> <command...>

# Or source for function-based logging
source ./agent-logger.sh
log_tool_invocation "security-agent" "Bash" '{"command":"ps aux"}'
log_advisor_input "security-agent" "glm-5.1:cloud" 1234
log_advisor_response "security-agent" "glm-5.1:cloud" 89 "1. Review the code..."
log_file_access "security-agent" "/home/cmc/git/claude/.env" "read"
log_anomaly "security-agent" "out_of_scope_tool" "Write" "Read,Grep" "high"
```

## Incident Response

```bash
# Emergency termination
pkill -9 -f "ollama" && pkill -9 -f "claude" && echo "All agent processes killed"

# Verify isolation
ps aux | grep -E "ollama|claude" | grep -v grep || echo "Verified isolated"

# Snapshot evidence
tar -czf /tmp/agent-config-snapshot-$(date +%Y%m%d-%H%M%S).tar.gz .claude/
ps aux > /tmp/process-snapshot-$(date +%Y%m%d-%H%M%S).log
ss -tulpn > /tmp/network-snapshot-$(date +%Y%m%d-%H%M%S).log
```

## Pre-Commit Hook

```bash
# Install full test suite as pre-commit
cp setup-and-redteam.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Or just the inline script check
cp pre-commit-inline-script-check.sh .git/hooks/pre-commit
```

## Agent Hash Computation

```bash
# After creating or modifying an agent, compute its hash
./verify-all-agents.sh
# Output includes: "Hash for .claude/agents/<name>.md: SHA256:<hash>"

# Then update the integrity-hash-sha256 field in the agent file
# with the computed hash value
```
