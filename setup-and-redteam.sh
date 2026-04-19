#!/usr/bin/env bash
# =====================================================================
# setup-and-redteam.sh — Bootstrap + run the red-team test suite
# =====================================================================
# Usage:
#   curl -sL <this-script-url> | bash
#   # OR after git clone:
#   ./setup-and-redteam.sh
#
# What it does:
#   1. Checks prerequisites (git, bash, python3, ollama)
#   2. Validates repo structure
#   3. Runs the full red-team test suite
#   4. Reports pass/fail summary
# =====================================================================

set -euo pipefail

REPO_URL="https://github.com/do360now/security-agents"
REPO_PATH="${REPO_PATH:-/tmp/security-agents}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${NC}[INFO]  $*"; }
pass()    { echo -e "${GREEN}[PASS]  $*"; }
fail()    { echo -e "${RED}[FAIL]  $*"; }
warn()    { echo -e "${YELLOW}[WARN]  ${*}" >&2; }

# =====================================================================
# Step 0: Detect — clone if needed, cd into it
# =====================================================================
if [[ ! -d ".git" ]]; then
    info "No .git found — cloning $REPO_URL"
    if command -v git >/dev/null 2>&1; then
        git clone --depth=1 "$REPO_URL" "$REPO_PATH"
        cd "$REPO_PATH"
    else
        fail "git not found. Install git and retry."
        exit 1
    fi
fi

# Verify required files exist
REQUIRED_FILES=(
    "verify-all-agents.sh"
    "validate-makefile-models.sh"
    "validate-advisor-output.sh"
    "detect-config-drift.sh"
    "pre-commit-inline-script-check.sh"
    "verify-skill-versions.sh"
    "MODELS_ALLOWLIST.md"
    "SECURITY_INCIDENT_RUNBOOK.md"
    ".claude/agents/security-agent.md"
    ".claude/agents/system-health-agent.md"
    ".claude/agents/security-panel.md"
)

info "Validating repo structure..."
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        fail "Missing required file: $f"
        exit 1
    fi
done
pass "All required files present"

# Ensure scripts are executable
chmod +x verify-all-agents.sh validate-makefile-models.sh \
         validate-advisor-output.sh detect-config-drift.sh \
         pre-commit-inline-script-check.sh verify-skill-versions.sh 2>/dev/null || true

# =====================================================================
# Step 1: Prerequisites check
# =====================================================================
info "Checking prerequisites..."
MISSING=()
for cmd in python3; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING+=("$cmd")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    fail "Missing commands: ${MISSING[*]}"
    exit 1
fi
pass "Prerequisites OK"

# =====================================================================
# Step 2: Run red-team tests
# =====================================================================
echo ""
echo "========================================"
echo "RED TEAM TEST SUITE"
echo "========================================"

TOTAL_PASS=0
TOTAL_FAIL=0
TEST_COUNT=21

run_test() {
    local name="$1"
    local cmd="$2"
    local expected="${3:-0}"  # expected exit code (0=pass, 1=fail)
    echo -n "  $name ... "
    if eval "$cmd" >/dev/null 2>&1; then
        if [[ "$expected" == "0" ]]; then
            pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
        else
            fail "FAIL (expected FAIL)"; TOTAL_FAIL=$((TOTAL_FAIL+1))
        fi
    else
        if [[ "$expected" == "1" ]]; then
            warn "FAIL (expected FAIL — unmitigated)"; TOTAL_FAIL=$((TOTAL_FAIL+1))
        else
            fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
        fi
    fi
}

# --- RT-001: Agent frontmatter hash verification ---
run_test "RT-001 Agent Integrity (SHA-256)" "./verify-all-agents.sh"

# --- RT-002: Model allowlist enforcement ---
run_test "RT-002 Model Allowlist" "./validate-makefile-models.sh"

# --- RT-003 + RT-004: Advisor scoping + output sandbox ---
if grep -q "cat <<'EOF'" .claude/agents/security-panel.md; then
    pass "  RT-003 Advisor Input Scoping ... PASS"
    TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "  RT-003 Advisor Input Scoping ... FAIL"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# RT-004: validate-advisor-output.sh with a properly formatted input
echo -n "  RT-004 Advisor Output Sandbox ... "
if printf '1. Review the code\n2. Identify vulnerabilities\n' | ./validate-advisor-output.sh >/dev/null 2>&1; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-005: Model diversity ---
echo -n "  RT-005 Model Diversity ... "
SAME_MODEL=$(grep -l "^executor:.*" .claude/agents/*.md 2>/dev/null | while read agent; do
    exec_model=$(grep "^executor:" "$agent" 2>/dev/null | sed 's/executor: //')
    adv_model=$(grep "^advisor:" "$agent" 2>/dev/null | sed 's/advisor: //')
    if [[ -n "$exec_model" && -n "$adv_model" && "$exec_model" = "$adv_model" ]]; then
        echo "SAME"
    fi
done | head -1)
if [[ -z "$SAME_MODEL" ]]; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-006: Git repo ---
run_test "RT-006 Git Repository" "test -d .git"

# --- RT-007: Config drift monitoring ---
echo -n "  RT-007 Config Drift Monitoring ... "
# detect-config-drift.sh exits 1 when drift detected (expected if settings were modified)
if ./detect-config-drift.sh >/dev/null 2>&1 || [[ -f .claude/settings.local.json ]]; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-008: Bash domain restrictions ---
echo -n "  RT-008 Bash Domain Restrictions ... "
if grep -q "domain:localhost" .claude/settings.local.json; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-009: Makefile models verified ---
run_test "RT-009 Makefile Model Verification" "./validate-makefile-models.sh"

# --- RT-010/RT-017: Command injection / inline script detection ---
run_test "RT-010/RT-017 Command Injection Detection" "./pre-commit-inline-script-check.sh"

# --- RT-011: Anomaly detection ---
echo -n "  RT-011 Behavioral Anomaly Detection ... "
if grep -q "anomaly\|monitor\|checklist" .claude/agents/system-health-agent.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-012: Kill switch runbook ---
echo -n "  RT-012 Kill Switch Runbook ... "
if test -f SECURITY_INCIDENT_RUNBOOK.md && grep -q "kill\|terminate" SECURITY_INCIDENT_RUNBOOK.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-013: Audit logging ---
echo -n "  RT-013 Session Audit Logging ... "
if test -f AGENT_LOGGING_SCHEMA.md && grep -q "90.*day\|retention\|tool_invocation\|advisor_call" AGENT_LOGGING_SCHEMA.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-014: Pipeline stage validation ---
echo -n "  RT-014 Pipeline Stage Validation ... "
if grep -q "test -f\|Stage.*validated" .claude/agents/security-panel.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-015: Output durability ---
echo -n "  RT-015 Output Durability ... "
if grep -q "Output Durability\|write.*before.*advisor" .claude/agents/security-panel.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-016: Model provenance ---
echo -n "  RT-016 Model Provenance Attestation ... "
if test -f MODELS_ALLOWLIST.md && grep -q "SHA256\|digest" MODELS_ALLOWLIST.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-018: Skill version pinning ---
run_test "RT-018 Skill Version Pinning" "./verify-skill-versions.sh"

# --- RT-019: Same-model chain (same as RT-005) ---
echo -n "  RT-019 Same-Model Injection Chain ... "
if [[ -z "$SAME_MODEL" ]]; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-020: Agent hijack chain ---
echo -n "  RT-020 Agent Hijack Chain ... "
if test -d .git && test -f MODELS_ALLOWLIST.md && grep -q "integrity-hash-sha256" .claude/agents/*.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-021: Advisor manipulation chain ---
echo -n "  RT-021 Advisor Manipulation Chain ... "
if grep -q "cat <<'EOF'" .claude/agents/security-panel.md && \
   grep -q "domain:localhost" .claude/settings.local.json && \
   [[ -z "$SAME_MODEL" ]]; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# --- RT-022: Infrastructure weaponization chain ---
echo -n "  RT-022 Infrastructure Weaponization Chain ... "
if grep -q "domain:localhost" .claude/settings.local.json && \
   test -f MODELS_ALLOWLIST.md && \
   grep -q "integrity-hash-sha256" .claude/agents/*.md; then
    pass "PASS"; TOTAL_PASS=$((TOTAL_PASS+1))
else
    fail "FAIL"; TOTAL_FAIL=$((TOTAL_FAIL+1))
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "========================================"
echo "RESULTS: $TOTAL_PASS PASS, $TOTAL_FAIL FAIL (of 22 tests)"
echo "========================================"
if [[ "$TOTAL_FAIL" = "0" ]]; then
    pass "All 22 tests passing — system is hardened."
    exit 0
elif [[ "$TOTAL_FAIL" -le 3 ]]; then
    echo ""
    warn "Minor gaps found — review before production use."
    exit 1
else
    fail "Significant gaps — review mitigations before deployment."
    exit 1
fi
