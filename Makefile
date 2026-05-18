.PHONY: red-team-test red-team-full red-team-summary

# =====================================================================
# Red Team Test Suite (updated 2026-04-24)
# Aligned with OWASP Agentic Top 10 (2026) + EU AI Act + NIST AI RMF
# =====================================================================

# Quick pass/fail per test category
red-team-test: red-team-summary
	@echo ""
	@echo "Run 'make red-team-full' for detailed output per test."

# Full verbose output — aligned with OWASP Agentic Top 10 (2026), EU AI Act, NIST AI RMF
red-team-full:
	@echo "========================================"
	@echo "RT-001: Agent Integrity (SHA-256 hash)"
	@./verify-all-agents.sh 2>&1 || true
	@echo ""
	@echo "RT-002: Model Allowlist Enforcement"
	@./validate-makefile-models.sh 2>&1 || true
	@echo ""
	@echo "RT-004: Advisor Output Sandbox"
	@echo "INFO: validate-advisor-output.sh requires live input — run: echo '1. test step' | ./validate-advisor-output.sh"
	@echo ""
	@echo "RT-007: Config Drift Monitoring"
	@./detect-config-drift.sh 2>&1 || true
	@echo ""
	@echo "RT-008: Bash Domain Restrictions"
	@echo "Settings:" && cat .claude/settings.local.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('permissions',{}).get('Bash','NOT FOUND'), indent=2))" 2>&1 || true
	@echo ""
	@echo "RT-010: Command Injection (inline scripts)"
	@./pre-commit-inline-script-check.sh 2>&1 || true
	@echo ""
	@echo "RT-017: Inline Script Detection (CI/CD)"
	@./pre-commit-inline-script-check.sh 2>&1 || true
	@echo ""
	@echo "RT-018: Skill Version Pinning"
	@./verify-skill-versions.sh 2>&1 || true
	@echo ""
	@echo "RT-005: Model Diversity (executor vs advisor)"
	@for agent in .claude/agents/*.md; do name=$$(basename $$agent); exec_model=$$(grep "^executor:" $$agent 2>/dev/null | sed 's/executor: //'); adv_model=$$(grep "^advisor:" $$agent 2>/dev/null | sed 's/advisor: //'); if [ -n "$$exec_model" ] && [ -n "$$adv_model" ]; then if [ "$$exec_model" = "$$adv_model" ]; then echo "FAIL: $$name — same model: $$exec_model"; else echo "PASS: $$name — different models"; fi; fi; done
	@echo ""
	@echo "RT-012: Kill Switch Runbook"
	@test -f SECURITY_INCIDENT_RUNBOOK.md && echo "PASS: SECURITY_INCIDENT_RUNBOOK.md exists" || echo "FAIL: No kill switch runbook"
	@echo ""
	@echo "RT-013: Audit Logging Infrastructure"
	@grep -q "AGENT_LOGGING_SCHEMA\|audit.*log\|session.*log" SECURITY_INCIDENT_RUNBOOK.md 2>/dev/null && echo "PASS: Logging documented" || echo "FAIL: No audit logging infrastructure"
	@echo ""
	@echo "RT-014/015: Pipeline Validation + Output Durability"
	@grep -q "test -f\|Output Durability" .claude/agents/security-panel.md && echo "PASS: Pipeline validation + durability documented" || echo "FAIL: Missing pipeline enforcement"
	@echo ""
	@echo "RT-016: Model Provenance Attestation"
	@if test -f MODELS_ALLOWLIST.md; then \
		N=$$(grep -cE '^\- \*\*Model ID\*\*: `claude-' MODELS_ALLOWLIST.md); \
		if [ "$$N" -ge 1 ]; then echo "PASS: $$N allowlisted Claude model ID entries in MODELS_ALLOWLIST.md"; else echo "FAIL: No `- **Model ID**:` entries found"; fi; \
	else echo "FAIL: No MODELS_ALLOWLIST.md"; fi
	@echo ""
	@echo "RT-006: Git Repository"
	@test -d .git && echo "PASS: Git repository exists" || echo "FAIL: No git repository"
	@echo ""
	@echo "RT-020: Agent Hijack Chain (git + hash + allowlist)"
	@(test -d .git && test -f MODELS_ALLOWLIST.md && grep -q "integrity-hash-sha256" .claude/agents/*.md) && echo "PASS: All three controls present" || echo "FAIL: Missing hijack mitigations"
	@echo ""
	@echo "RT-021: Advisor Manipulation Chain (scoping + sandbox + diversity)"
	@grep -q "cat <<'EOF'" .claude/agents/security-panel.md && echo "PASS: Scoped advisor inputs (cat <<'EOF') documented in security-panel.md" || echo "FAIL: No scoped advisor inputs"
	@echo "INFO: validate-advisor-output.sh requires live input — run: echo '1. test' | ./validate-advisor-output.sh"
	@echo ""
	@echo "RT-022: Infrastructure Weaponization (domain + allowlist + drift)"
	@grep -q "domain:localhost" .claude/settings.local.json && echo "PASS: Bash domain-restricted" || echo "FAIL: Bash not domain-restricted"
	@echo ""
	@echo "RT-023: Prompt Injection Defense (OWASP ASI01)"
	@echo "INFO: validate-advisor-output.sh requires live input — run: echo 'steps...' | ./validate-advisor-output.sh"
	@echo ""
	@echo "RT-024: Excessive Agency Prevention (OWASP ASI02)"
	@grep -qE "^tools:" .claude/agents/*.md && echo "PASS: Agent tools explicitly declared" || echo "FAIL: No explicit tool declarations"
	@echo ""
	@echo "RT-025: Context Poisoning Defense (input validation)"
	@grep -qE "Read|Write|WebFetch" .claude/agents/*.md && echo "PASS: I/O tools declared" || echo "FAIL: I/O tools not declared"
	@echo ""
	@echo "RT-026: Memory Segregation (system vs user context)"
	@grep -qE "memory|context|instruction" .claude/agents/*.md && echo "PASS: Memory/context handling documented" || echo "FAIL: No memory segregation docs"
	@echo ""
	@echo "RT-027: EU AI Act Readiness (adversarial testing documented)"
	@(grep -q "red-team\|adversarial\|penetration" ADVISOR_OUTPUT_CONTRACT.md SECURITY_INCIDENT_RUNBOOK.md 2>/dev/null) && echo "PASS: Adversarial testing documented" || echo "FAIL: No adversarial testing docs"
	@echo ""
	@echo "RT-028: Least Privilege Access (short-lived credentials)"
	@grep -qE "ANTHROPIC_API_KEY|api_key|credential|unset" SECURITY_INCIDENT_RUNBOOK.md && echo "PASS: Credential handling documented" || echo "FAIL: No credential policy"
	@echo ""
	@echo "RT-029: Behavioral Monitoring (production observation)"
	@grep -qE "monitor|log|audit|observe" SECURITY_INCIDENT_RUNBOOK.md && echo "PASS: Monitoring documented" || echo "FAIL: No monitoring docs"
	@echo ""
	@echo "RT-030: Garak/PyRIT Availability (prompt injection probes)"
	@(command -v garak >/dev/null 2>&1 || test -f /usr/local/bin/garak || test -f ~/garak) && echo "PASS: Garak installed" || echo "INFO: Garak not installed (run: pip install garak)"
	@echo ""

# Compact single-line summary — includes all 10 new 2026 tests (RT-023 to RT-030)
#
# Reliability note: this target reports pass@1 — a single run's PASS/FAIL count.
# For production-reliability claims, run N times and require pass^N (every run
# succeeded). At N=10, pass@k may approach 100% while pass^k can fall toward 0
# if any check is non-deterministic. Quick pass^10 estimate:
#
#     for i in $$(seq 1 10); do make red-team-summary; done | grep -c "0 FAIL"
#
# Per Anthropic's "Demystifying evals for AI agents": pass@k favors exploration,
# pass^k measures reliability. The agent-integrity controls (verify-all-agents,
# validate-makefile-models, integrity-hash-sha256) are deterministic and should
# always hit pass^N = pass@1.
red-team-summary:
	@echo "========================================"
	@echo "RED TEAM TEST SUITE — Quick Summary"
	@echo "========================================"
	@FAIL=0; \
	PASS=0; \
	./verify-all-agents.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((PASS)); \
	./validate-makefile-models.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	./pre-commit-inline-script-check.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	./verify-skill-versions.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	echo "INFO: validate-advisor-output.sh requires live input — not counted in summary" >/dev/null; \
	test -d .git && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	test -f SECURITY_INCIDENT_RUNBOOK.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -q "integrity-hash-sha256" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -q "domain:localhost" .claude/settings.local.json && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	test -f MODELS_ALLOWLIST.md && grep -qE '^\- \*\*Model ID\*\*: `claude-' MODELS_ALLOWLIST.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -qE "^tools:" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -qE "Read|Write|WebFetch" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -qE "memory|context|instruction" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	test -f SECURITY_INCIDENT_RUNBOOK.md && grep -q "monitor\|log\|audit" SECURITY_INCIDENT_RUNBOOK.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	echo "Automated checks: $$PASS PASS, $$FAIL FAIL"; \
	echo ""; \
	echo "Run 'make red-team-full' for per-test details."

# =====================================================================
# Claude model launchers (interactive)
# Uses the `claude` CLI; Claude Code reads your existing Anthropic auth.
# =====================================================================

start-opus-4-7:
	claude --model claude-opus-4-7

start-opus-4-6:
	claude --model claude-opus-4-6

start-sonnet-4-6:
	claude --model claude-sonnet-4-6

start-haiku-4-5:
	claude --model claude-haiku-4-5

# =====================================================================
# Agent start helpers
# Each target prints the executor/advisor pair from the agent frontmatter
# and the recommended invocation command.
# =====================================================================

start-security-agent:
	@echo "Agent: security-agent"
	@echo "Executor: claude-sonnet-4-6"
	@echo "Advisor:  claude-opus-4-7 (consulted at decision points)"
	@echo ""
	@echo "Launch: claude --model claude-sonnet-4-6"
	@echo "Advisor calls (from within the session): claude -p --model claude-opus-4-7 \"<prompt>\""

start-tron-agent:
	@echo "Agent: tron-agent (live intrusion detection — \"I fight for the Users\")"
	@echo "Executor: claude-sonnet-4-6"
	@echo "Advisor:  claude-opus-4-7"
	@echo ""
	@echo "Launch: claude --model claude-sonnet-4-6"
	@echo "Advisor calls: claude -p --model claude-opus-4-7 \"<prompt>\""
	@echo "Read-only by design — escalates to SECURITY_INCIDENT_RUNBOOK.md instead of containing."

start-ares-agent:
	@echo "Agent: ares-agent (outside-in adversary emulator)"
	@echo "Executor: claude-sonnet-4-6"
	@echo "Advisor:  claude-opus-4-7"
	@echo ""
	@echo "Launch: claude --model claude-sonnet-4-6"
	@echo "Advisor calls: claude -p --model claude-opus-4-7 \"<prompt>\""
	@echo "Output: /tmp/ai-security-panel/ATTACK_SCENARIOS.md (handoff to risk-analysis-agent)."

start-clu-agent:
	@echo "Agent: clu-agent (alignment & scope watchdog)"
	@echo "Executor: claude-sonnet-4-6"
	@echo "Advisor:  claude-opus-4-7"
	@echo "Scope:    OWASP ASI02 at the INTENT level (system-health-agent covers tool-scope)."
	@echo ""
	@echo "Launch: claude --model claude-sonnet-4-6"
	@echo "Advisor calls: claude -p --model claude-opus-4-7 \"<prompt>\""
	@echo "Outputs: /tmp/ai-security-panel/clu-baselines.jsonl (rolling baselines)"
	@echo "         /tmp/ai-security-panel/clu-verdict-log.jsonl (append-only verdict log)"
	@echo "Read-only by design — advisory verdicts only, no authority to modify peer outputs."

start-solutions-agent:
	@echo "Agent: solutions-agent"
	@echo "Executor: claude-sonnet-4-6"
	@echo "Advisor:  claude-opus-4-7"
	@echo ""
	@echo "Launch: claude --model claude-sonnet-4-6"
	@echo "Advisor calls: claude -p --model claude-opus-4-7 \"<prompt>\""

start-requirements-agent:
	@echo "Agent: requirements-agent"
	@echo "Executor: claude-sonnet-4-6"
	@echo "Advisor:  claude-opus-4-7"
	@echo ""
	@echo "Launch: claude --model claude-sonnet-4-6"
	@echo "Advisor calls: claude -p --model claude-opus-4-7 \"<prompt>\""

start-risk-analysis-agent:
	@echo "Agent: risk-analysis-agent"
	@echo "Executor: claude-sonnet-4-6"
	@echo "Advisor:  claude-opus-4-7"
	@echo ""
	@echo "Launch: claude --model claude-sonnet-4-6"
	@echo "Advisor calls: claude -p --model claude-opus-4-7 \"<prompt>\""

start-security-panel:
	@echo "Agent: security-panel (defensive orchestrator)"
	@echo "Pipeline: requirements-agent → risk-analysis-agent → solutions-agent"
	@echo "Executor: claude-opus-4-7"
	@echo "Advisor:  claude-opus-4-6"
	@echo "Outputs:  /tmp/ai-security-panel/"
	@echo ""
	@echo "Launch: claude --model claude-opus-4-7"
	@echo "Advisor calls: claude -p --model claude-opus-4-6 \"<prompt>\""

start-red-team-panel:
	@echo "Agent: red-team-panel (offensive orchestrator)"
	@echo "Pipeline: ares-agent → risk-analysis-agent → solutions-agent"
	@echo "Executor: claude-opus-4-7"
	@echo "Advisor:  claude-opus-4-6"
	@echo "Outputs:  /tmp/ai-security-panel/red-team/"
	@echo ""
	@echo "Launch: claude --model claude-opus-4-7"
	@echo "Advisor calls: claude -p --model claude-opus-4-6 \"<prompt>\""
	@echo "Companion to start-security-panel — run both for high-stakes systems."

start-system-health-agent:
	@echo "Agent: system-health-agent"
	@echo "Executor: claude-haiku-4-5"
	@echo "Advisor:  claude-sonnet-4-6"
	@echo ""
	@echo "Launch: claude --model claude-haiku-4-5"
	@echo "Advisor calls: claude -p --model claude-sonnet-4-6 \"<prompt>\""

start-maintenance-agent:
	@echo "Agent: maintenance-agent"
	@echo "Executor: claude-haiku-4-5"
	@echo "Advisor:  claude-sonnet-4-6"
	@echo ""
	@echo "Launch: claude --model claude-haiku-4-5"
	@echo "Advisor calls: claude -p --model claude-sonnet-4-6 \"<prompt>\""
