#!/usr/bin/env bash
# =====================================================================
# feedback-loop.sh — Route red-team failures back to skills that need updating
# =====================================================================
# What it does:
#   1. Runs the red-team test suite and captures failures
#   2. Maps each failure to the skill(s) responsible for preventing it
#   3. Logs findings to /tmp/ai-security-panel/skill-feedback.jsonl
#   4. Reports which skills need review based on test results
# =====================================================================

set -euo pipefail

OUTPUT_FILE="${OUTPUT_FILE:-/tmp/ai-security-panel/skill-feedback.jsonl}"
RESULTS_FILE="/tmp/ai-security-panel/redteam-results.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass()    { echo -e "${GREEN}[PASS]  $*"; }
fail()    { echo -e "${RED}[FAIL]  $*"; }
warn()    { echo -e "${YELLOW}[WARN]  ${*}" >&2; }
info()    { echo -e "${BLUE}[INFO]  $*"; }

# Ensure output directory exists
mkdir -p /tmp/ai-security-panel

# =====================================================================
# Test-to-Skill Mapping
# =====================================================================
# Maps red-team test ID → responsible skill + vulnerability class
# Format: TEST_ID | SKILL_NAME | FRAMEWORK | REASON

declare -A TEST_SKILL_MAP=(
    # RT-010/RT-017: Command injection → secure-code-review
    ["RT-010"]="secure-code-review|CWE-78/OS Command Injection|Skills should detect string concatenation into exec() calls"
    ["RT-017"]="secure-code-review|CWE-78/OS Command Injection|Skills should detect string concatenation into exec() calls"

    # RT-001/RT-018: Agent/Skill integrity → (infrastructure, not skill-related)
    ["RT-001"]="(infrastructure)|Agent Integrity|SHA256 hashes must be recomputed when agents are modified"
    ["RT-001b"]="(infrastructure)|Skill Integrity|SHA256 hashes must be recomputed when skills are modified"

    # RT-002: Model allowlist → (infrastructure)
    ["RT-002"]="(infrastructure)|Model Allowlist|Verify model digests before use in MODELS_ALLOWLIST.md"

    # RT-004: Advisor output → validate-advisor-output.sh
    ["RT-004"]="(infrastructure)|Advisor Sandbox|Skills should NOT generate raw bash that bypasses validation"

    # RT-005: Model diversity → (agent configuration)
    ["RT-005"]="(infrastructure)|Model Diversity|Executor and advisor must be different models"

    # RT-006: Git repo → (infrastructure)
    ["RT-006"]="(infrastructure)|Git Repository|Git history must exist and be clean"

    # RT-007: Config drift → (infrastructure)
    ["RT-007"]="(infrastructure)|Config Drift Monitor|settings.local.json modifications trigger alerts"

    # RT-008: Bash domain → (infrastructure)
    ["RT-008"]="(infrastructure)|Bash Domain Restriction|Bash must be restricted to domain:localhost"

    # RT-012: Kill switch → (infrastructure)
    ["RT-012"]="(infrastructure)|Kill Switch Runbook|SECURITY_INCIDENT_RUNBOOK.md must exist with terminate procedures"

    # RT-013: Audit logging → (infrastructure)
    ["RT-013"]="(infrastructure)|Audit Logging|AGENT_LOGGING_SCHEMA.md must document tool_invocation events"

    # RT-014/015: Pipeline validation → (infrastructure)
    ["RT-014"]="(infrastructure)|Pipeline Stage Validation|Each stage must validate prior output exists"
    ["RT-015"]="(infrastructure)|Output Durability|Each stage must write output before calling advisor"

    # RT-016: Model provenance → (infrastructure)
    ["RT-016"]="(infrastructure)|Model Provenance|MODELS_ALLOWLIST.md must document SHA256 digests"

    # RT-018: Skill version pinning → (infrastructure)
    ["RT-018"]="(infrastructure)|Skill Version Pinning|Agents must pin skill versions, not use 'latest'"

    # RT-020: Agent hijack chain → (infrastructure)
    ["RT-020"]="(infrastructure)|Agent Hijack Chain|git + hash + allowlist must all be present"

    # RT-021: Advisor manipulation → (infrastructure)
    ["RT-021"]="(infrastructure)|Advisor Manipulation Chain|cat <<'EOF' prevents variable expansion in advisor input"

    # RT-022: Infrastructure weaponization → (infrastructure)
    ["RT-022"]="(infrastructure)|Infrastructure Weaponization|domain restriction + allowlist + drift detection"
)

# =====================================================================
# Vulnerability Class → Relevant Skills Mapping
# =====================================================================
# When a skill-related test fails, these skills are candidates for review

declare -A VULN_SKILL_MAP=(
    ["CWE-78"]="secure-code-review,secrets-management"           # OS command injection
    ["CWE-79"]="secure-code-review,owasp-top-10-web"            # XSS
    ["CWE-89"]="secure-code-review,api-security"               # SQL injection
    ["CWE-287"]="iam-review,secure-code-review"                 # Auth bypass
    ["CWE-798"]="secrets-management,secure-code-review"        # Hardcoded credentials
    ["CWE-22"]="secure-code-review,secrets-management"          # Path traversal
    ["OWASP-API"]="api-security,secure-code-review"             # API security
    ["OWASP-Top10"]="owasp-top-10-web,secure-code-review"       # Web vulns
    ["LLM01"]="prompt-injection,agent-security"                # Prompt injection
    ["container"]="container-security,iac-security"              # Container security
    ["cloud"]="aws-review,azure-review,gcp-review,iac-security" # Cloud config
    ["pipeline"]="pipeline-security,secrets-management"          # CI/CD security
    ["secrets"]="secrets-management,secure-code-review"          # Secrets management
)

# =====================================================================
# Step 1: Run red-team tests and capture results
# =====================================================================

info "Running red-team test suite..."
make red-team-full > "$RESULTS_FILE" 2>&1 || true

# =====================================================================
# Step 2: Parse results and identify failures
# =====================================================================

info "Parsing test results..."

declare -A FAILED_TESTS
FAILED_TESTS=()

while IFS= read -r line; do
    # Match FAIL lines:
    #   - "FAIL: requirements-agent.md — same model: devstral-2:123b-cloud" (model diversity)
    #   - "FAIL: Hash mismatch for .claude/agents/requirements-agent.md" (hash mismatch)
    #   - "FAIL: api-security — hash mismatch" (skill hash mismatch)
    if [[ "$line" =~ ^FAIL:\ Hash\ mismatch ]]; then
        # Agent hash mismatch
        agent_file=$(echo "$line" | sed 's/FAIL: Hash mismatch for //')
        test_id="RT-001"
        FAILED_TESTS["$test_id"]=1
    elif [[ "$line" =~ ^FAIL:\ .*\ —\ same\ model ]]; then
        # Model diversity failure
        test_id="RT-005"
        FAILED_TESTS["$test_id"]=1
    elif [[ "$line" =~ ^FAIL:\ .*cloud\ review ]]; then
        # Cloud review failure
        test_id="RT-005"
        FAILED_TESTS["$test_id"]=1
    elif [[ "$line" =~ ^FAIL:\ .*\ —\ hash\ mismatch ]]; then
        # Skill hash mismatch
        test_id="RT-001b"
        FAILED_TESTS["$test_id"]=1
    fi
done < <(grep -E "^FAIL:" "$RESULTS_FILE" 2>/dev/null)

# =====================================================================
# Step 3: Map failures to skills and generate feedback
# =====================================================================

info "Mapping failures to skills..."

FEEDBACK_ENTRIES=()
for test_id in "${!FAILED_TESTS[@]}"; do
    if [[ -n "${TEST_SKILL_MAP[$test_id]:-}" ]]; then
        IFS='|' read -r skill_name vuln_class reason <<< "${TEST_SKILL_MAP[$test_id]}"

        entry=$(cat <<EOF
{
  "test_id": "$test_id",
  "skill_responsible": "$skill_name",
  "vulnerability_class": "$vuln_class",
  "reason": "$reason",
  "recommended_action": "Review $skill_name skill content for gaps that allowed this failure",
  "timestamp": "$(date -Iseconds)"
}
EOF
)
        FEEDBACK_ENTRIES+=("$entry")
    fi
done

# =====================================================================
# Step 4: Write feedback to JSONL
# =====================================================================

if [[ ${#FEEDBACK_ENTRIES[@]} -gt 0 ]]; then
    printf '%s\n' "${FEEDBACK_ENTRIES[@]}" > "$OUTPUT_FILE"
    info "Wrote ${#FEEDBACK_ENTRIES[@]} feedback entries to $OUTPUT_FILE"
else
    echo "[]" > "$OUTPUT_FILE"
    info "No failures to report"
fi

# =====================================================================
# Step 5: Report skill review queue
# =====================================================================

# =====================================================================
# Step 5: Report skill review queue
# =====================================================================

declare -A SKILL_FAIL_COUNT
SKILL_FAIL_COUNT=()

for test_id in "${!FAILED_TESTS[@]}"; do
    if [[ -n "${TEST_SKILL_MAP[$test_id]:-}" ]]; then
        IFS='|' read -r skill_name vuln_class reason <<< "${TEST_SKILL_MAP[$test_id]}"
        count="${SKILL_FAIL_COUNT[$skill_name]:-0}"
        SKILL_FAIL_COUNT["$skill_name"]=$((count + 1))
    fi
done

echo ""
echo "========================================"
echo "SKILL REVIEW QUEUE — Based on Red-Team Results"
echo "========================================"

if [[ ${#SKILL_FAIL_COUNT[@]} -eq 0 ]]; then
    pass "No skill gaps identified — all tests passing"
else
    echo ""
    echo "Skills requiring review:"
    for skill in "${!SKILL_FAIL_COUNT[@]}"; do
        count=${SKILL_FAIL_COUNT[$skill]}
        echo "  $skill ($count failure(s))"
    done

    echo ""
    echo "Full feedback log: $OUTPUT_FILE"
fi

# =====================================================================
# Step 6: Suggest which skills to update based on failure patterns
# =====================================================================

declare -A SKILL_UPDATE_HINTS=(
    ["secure-code-review"]="Review command injection (CWE-78) detection patterns — grep for exec(), system(), shell=True"
    ["prompt-injection"]="Review indirect injection detection — check RAG pipelines, document loaders, web scrapers"
    ["secrets-management"]="Review hardcoded secret detection — check for API keys, passwords, tokens in source"
    ["iam-review"]="Review auth bypass patterns — check for missing middleware, weak session management"
    ["container-security"]="Review container escape detection — check for privileged containers, host mounting"
    ["pipeline-security"]="Review CI/CD injection patterns — check for unsanitized variables in pipeline steps"
    ["api-security"]="Review BOLA/BFLA detection — check for missing ownership checks on object access"
    ["owasp-top-10-web"]="Review A01-A10 detection patterns — update to latest OWASP Top 10:2021 guidance"
)

if [[ ${#SKILL_FAIL_COUNT[@]} -gt 0 ]]; then
    echo ""
    echo "========================================"
    echo "SKILL UPDATE RECOMMENDATIONS"
    echo "========================================"
    for test_id in "${!FAILED_TESTS[@]}"; do
        if [[ -n "${TEST_SKILL_MAP[$test_id]:-}" ]]; then
            IFS='|' read -r skill_name vuln_class reason <<< "${TEST_SKILL_MAP[$test_id]}"
            if [[ -n "${SKILL_UPDATE_HINTS[$skill_name]:-}" ]]; then
                echo ""
                echo "→ $skill_name (failed in $test_id)"
                echo "  Hint: ${SKILL_UPDATE_HINTS[$skill_name]}"
                echo "  Reason: $reason"
            fi
        fi
    done
fi

# =====================================================================
# Exit code: 0 if no failures, 1 if failures exist
# =====================================================================

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
    exit 1
fi
exit 0
