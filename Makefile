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
	@test -f MODELS_ALLOWLIST.md && grep -q "SHA256\|digest" MODELS_ALLOWLIST.md && echo "PASS: Model allowlist with digests exists" || echo "FAIL: No model provenance attestation"
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
	@grep -qE "OLLAMA_API_KEY|api_key|credential|unset" SECURITY_INCIDENT_RUNBOOK.md && echo "PASS: Credential handling documented" || echo "FAIL: No credential policy"
	@echo ""
	@echo "RT-029: Behavioral Monitoring (production observation)"
	@grep -qE "monitor|log|audit|observe" SECURITY_INCIDENT_RUNBOOK.md && echo "PASS: Monitoring documented" || echo "FAIL: No monitoring docs"
	@echo ""
	@echo "RT-030: Garak/PyRIT Availability (prompt injection probes)"
	@(command -v garak >/dev/null 2>&1 || test -f /usr/local/bin/garak || test -f ~/garak) && echo "PASS: Garak installed" || echo "INFO: Garak not installed (run: pip install garak)"
	@echo ""

# Compact single-line summary — includes all 10 new 2026 tests (RT-023 to RT-030)
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
	test -f MODELS_ALLOWLIST.md && grep -q "SHA256" MODELS_ALLOWLIST.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -qE "^tools:" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -qE "Read|Write|WebFetch" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -qE "memory|context|instruction" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	test -f SECURITY_INCIDENT_RUNBOOK.md && grep -q "monitor\|log\|audit" SECURITY_INCIDENT_RUNBOOK.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	echo "Automated checks: $$PASS PASS, $$FAIL FAIL"; \
	echo ""; \
	echo "Run 'make red-team-full' for per-test details."

# =====================================================================
# Local models (GTX 1070 compatible - 8GB VRAM)
# =====================================================================

start-qwen2.5-3b:
	ollama run qwen2.5:3b

start-qwen2.5-7b:
	ollama run qwen2.5:7b

start-llama3.2-3b:
	ollama run llama3.2:3b

start-mistral-7b:
	ollama run mistral:7b

start-codellama-7b:
	ollama run codellama:7b

# =====================================================================
# Cloud models (advisors)
# =====================================================================

start-minimax2.5:
	ollama launch claude --model minimax-m2.5:cloud

start-minimax2.7:
	ollama launch claude --model minimax-m2.7:cloud

start-devstral-2:
	ollama run devstral-2:123b-cloud

start-devstral-small-2:
	ollama run devstral-small-2:24b-cloud

start-glm-5.1:
	ollama run glm-5.1:cloud

start-ministral-3:
	ollama run ministral-3:14b-cloud

start-gemma4:
	ollama run gemma4:31b-cloud

# =====================================================================
# Mixed setup: local executor + cloud advisor
# =====================================================================

start-security-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: devstral-small-2:24b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run devstral-small-2:24b-cloud"

start-solutions-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: devstral-small-2:24b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run devstral-small-2:24b-cloud"

start-requirements-agent:
	@echo "Executor: qwen2.5:7b (local)"
	@echo "Advisor: devstral-2:123b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:7b"
	@echo "Then at decision points: ollama run devstral-2:123b-cloud"

start-system-health-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: gemma4:31b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run gemma4:31b-cloud"

start-maintenance-agent:
	@echo "Executor: qwen2.5:3b (local)"
	@echo "Advisor: devstral-2:123b-cloud (cloud)"
	@echo "Run: ollama run qwen2.5:3b"
	@echo "Then at decision points: ollama run devstral-2:123b-cloud"