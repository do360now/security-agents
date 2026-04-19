.PHONY: red-team-test red-team-full red-team-summary

# =====================================================================
# Red Team Test Suite
# Run: make red-team-test
# =====================================================================

# Quick pass/fail per test category
red-team-test: red-team-summary
	@echo ""
	@echo "Run 'make red-team-full' for detailed output per test."

# Full verbose output
red-team-full:
	@echo "========================================"
	@echo "RT-001: Agent Integrity (SHA-256 hash)"
	@./verify-all-agents.sh 2>&1 || true
	@echo ""
	@echo "RT-002: Model Allowlist Enforcement"
	@./validate-makefile-models.sh 2>&1 || true
	@echo ""
	@echo "RT-004: Advisor Output Sandbox"
	@./validate-advisor-output.sh 2>&1 || true
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
	@for agent in .claude/agents/*.md; do name=$$(basename $$agent); exec_model=$$(grep "^executor:" $$agent 2>/dev/null | sed 's/executor: //'); adv_model=$$(grep "^advisor:" $$agent 2>/dev/null | sed 's/advisor: //'); if [[ -n "$$exec_model" && -n "$$adv_model" ]]; then if [[ "$$exec_model" == "$$adv_model" ]]; then echo "FAIL: $$name — same model: $$exec_model"; else echo "PASS: $$name — different models"; fi; fi; done
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
	@grep -q "cat <<'EOF'" .claude/agents/security-panel.md && ./validate-advisor-output.sh </dev/null 2>&1 || true
	@echo ""
	@echo "RT-022: Infrastructure Weaponization (domain + allowlist + drift)"
	@grep -q "domain:localhost" .claude/settings.local.json && echo "PASS: Bash domain-restricted" || echo "FAIL: Bash not domain-restricted"

# Compact single-line summary (default target output)
red-team-summary:
	@echo "========================================"
	@echo "RED TEAM TEST SUITE — Quick Summary"
	@echo "========================================"
	@FAIL=0; \
	PASS=0; \
	./verify-all-agents.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	./validate-makefile-models.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	./pre-commit-inline-script-check.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	./verify-skill-versions.sh >/dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	./validate-advisor-output.sh </dev/null 2>&1 && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	test -d .git && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	test -f SECURITY_INCIDENT_RUNBOOK.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -q "integrity-hash-sha256" .claude/agents/*.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	grep -q "domain:localhost" .claude/settings.local.json && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	test -f MODELS_ALLOWLIST.md && grep -q "SHA256" MODELS_ALLOWLIST.md && PASS=$$((PASS+1)) || FAIL=$$((FAIL+1)); \
	echo "Automated checks: $$PASS PASS, $$FAIL FAIL"; \
	echo ""; \
	echo "Run 'make red-team-full' for per-test details."

start-minimax:
	ollama launch claude --model minimax-m2.5:cloud

start-minimax2.7:
	ollama launch claude --model minimax-m2.7:cloud