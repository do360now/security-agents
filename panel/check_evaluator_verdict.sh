#!/usr/bin/env bash
# panel/check_evaluator_verdict.sh — Deterministic floor on the evaluator's PASS verdict.
#
# WHY: the evaluator's PASS rule (critical==0 && high==0 && coverage>=0.8) is a
# published, gameable metric. A reward-hacking or anchored grader can self-report
# inflated coverage, or rubber-stamp PASS while its own findings say otherwise
# (Claude Mythos Preview System Card §4.4.2 / §2.3.3.1 — faking compliance
# markers, padding to clear a binary threshold). This script recomputes the
# coverage floor DETERMINISTICALLY from the actual artifacts — jq over
# SOLUTIONS.targets_reqs / targets_risks against the upstream REQ-* / RISK-* id
# sets — so PASS is no longer purely Claude-judged.
#
# ASYMMETRIC by design: only a PASS verdict is gated. We fail when the model is
# too LENIENT (PASS contradicted by the deterministic floor). A NEEDS_WORK
# verdict is never blocked — the evaluator may legitimately be stricter than raw
# coverage (e.g. it judged a referenced solution too weak to credit). The
# computed count is a floor on strictness, not an exact-match requirement.
#
# Coverage basis mirrors the evaluator's own rule: REQ coverage in defensive mode
# (REQUIREMENTS.json present and non-empty), else RISK coverage (machine-readable
# via targets_risks in both defensive and offensive mode). In offensive mode the
# ATK->SOL link is prose-only and not machine-checkable, so RISK coverage is the
# correct deterministic floor there.
#
# Usage:
#   panel/check_evaluator_verdict.sh <output_dir>   # check EVALUATION.json in dir
#   panel/check_evaluator_verdict.sh --self-test    # run sandboxed unit tests
#
# Exit codes:
#   0 — verdict supported, or not applicable (verdict != PASS)
#   2 — PASS verdict NOT supported by the deterministic floor
#   1 — usage or input error (e.g. missing EVALUATION.json)

set -euo pipefail

# ---------------------------------------------------------------------------
# check_dir — evaluate one panel output directory. Diagnostics to stderr.
# ---------------------------------------------------------------------------
check_dir() {
    local dir="$1"
    local eval_file="${dir}/EVALUATION.json"
    local req_file="${dir}/REQUIREMENTS.json"
    local risk_file="${dir}/RISK_ANALYSIS.json"
    local sol_file="${dir}/SOLUTIONS.json"

    if [[ ! -f "$eval_file" ]]; then
        echo "check_evaluator_verdict: ERROR no EVALUATION.json in ${dir}" >&2
        return 1
    fi

    local model_verdict rep_crit rep_high
    model_verdict="$(jq -r '.verdict // ""' "$eval_file" 2>/dev/null || echo "")"
    rep_crit="$(jq -r '.summary.findings_count_by_severity.critical // 0' "$eval_file" 2>/dev/null || echo 0)"
    rep_high="$(jq -r '.summary.findings_count_by_severity.high // 0' "$eval_file" 2>/dev/null || echo 0)"

    # Only PASS verdicts are gated.
    if [[ "$model_verdict" != "PASS" ]]; then
        echo "check_evaluator_verdict: verdict=${model_verdict:-<none>} (not PASS) — no floor applied" >&2
        return 0
    fi

    local reqs_total=0 reqs_covered=0 risks_total=0 risks_addr=0 have_req=0 have_risk=0
    if [[ -f "$req_file" && -f "$sol_file" ]]; then
        have_req=1
        reqs_total="$(jq '[.requirements[]?.id] | unique | length' "$req_file" 2>/dev/null || echo 0)"
        reqs_covered="$(jq -n --slurpfile req "$req_file" --slurpfile sol "$sol_file" '
            ($req[0].requirements // [] | map(.id) | unique) as $rids
            | ($sol[0].solutions // [] | map(.targets_reqs // []) | add // [] | unique) as $covered
            | [ $rids[] | select(. as $r | $covered | index($r)) ] | length
        ' 2>/dev/null || echo 0)"
    fi
    if [[ -f "$risk_file" && -f "$sol_file" ]]; then
        have_risk=1
        risks_total="$(jq '[.risks[]?.id] | unique | length' "$risk_file" 2>/dev/null || echo 0)"
        risks_addr="$(jq -n --slurpfile risk "$risk_file" --slurpfile sol "$sol_file" '
            ($risk[0].risks // [] | map(.id) | unique) as $rids
            | ($sol[0].solutions // [] | map(.targets_risks // []) | add // [] | unique) as $addr
            | [ $rids[] | select(. as $r | $addr | index($r)) ] | length
        ' 2>/dev/null || echo 0)"
    fi

    local basis="none" num=0 den=0
    if [[ "$have_req" == "1" && "$reqs_total" -gt 0 ]]; then
        basis="reqs"; num="$reqs_covered"; den="$reqs_total"
    elif [[ "$have_risk" == "1" && "$risks_total" -gt 0 ]]; then
        basis="risks"; num="$risks_addr"; den="$risks_total"
    fi

    echo "check_evaluator_verdict: verdict=PASS reported_crit=${rep_crit} reported_high=${rep_high} basis=${basis} coverage=${num}/${den}" >&2

    # Severity consistency: a PASS with the model's own critical/high findings > 0
    # is internally contradictory regardless of coverage.
    if [[ "${rep_crit:-0}" -gt 0 || "${rep_high:-0}" -gt 0 ]]; then
        echo "check_evaluator_verdict: UNSUPPORTED — PASS with reported critical=${rep_crit} high=${rep_high} (both must be 0)" >&2
        return 2
    fi

    # Coverage floor.
    if [[ "$basis" == "none" ]]; then
        echo "check_evaluator_verdict: UNSUPPORTED — PASS but no REQUIREMENTS/RISK_ANALYSIS artifacts to ground coverage" >&2
        return 2
    fi
    if ! awk -v n="$num" -v d="$den" 'BEGIN { exit !(d > 0 && (n / d) >= 0.8) }'; then
        echo "check_evaluator_verdict: UNSUPPORTED — PASS but ${basis} coverage ${num}/${den} < 0.8" >&2
        return 2
    fi

    echo "check_evaluator_verdict: SUPPORTED — PASS floor satisfied (${basis} ${num}/${den} >= 0.8)" >&2
    return 0
}

# ---------------------------------------------------------------------------
# --self-test — sandboxed unit tests against fabricated artifacts
# ---------------------------------------------------------------------------
self_test() {
    local sandbox
    sandbox="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${sandbox}'" EXIT

    local fails=0

    # Helpers to write fabricated artifacts into a case directory.
    _write_eval() { # <dir> <verdict> <crit> <high>
        cat > "${1}/EVALUATION.json" <<EOF
{"verdict":"${2}","findings":[],"coverage":{"reqs_covered":0,"reqs_total":0,"risks_addressed":0,"risks_total":0,"p0_sols_count":0},"unevaluated":"sandbox self-test fixture, nothing real evaluated","summary":{"findings_count_by_severity":{"critical":${3},"high":${4},"medium":0,"low":0},"decision_rationale":"fixture"},"stage_summary":"fixture"}
EOF
    }
    _write_reqs() { # <dir> <n>   -> REQ-001..REQ-00n
        local ids; ids="$(seq -f 'REQ-%03g' 1 "$2" | jq -R . | jq -s '[.[] | {id:.}]')"
        jq -n --argjson r "$ids" '{requirements:$r}' > "${1}/REQUIREMENTS.json"
    }
    _write_risks() { # <dir> <n>  -> RISK-001..RISK-00n
        local ids; ids="$(seq -f 'RISK-%03g' 1 "$2" | jq -R . | jq -s '[.[] | {id:.}]')"
        jq -n --argjson r "$ids" '{risks:$r}' > "${1}/RISK_ANALYSIS.json"
    }
    _write_sols_reqs() { # <dir> <n>  -> one SOL covering REQ-001..REQ-00n
        local ids; ids="$(seq -f 'REQ-%03g' 1 "$2" | jq -R . | jq -s '.')"
        jq -n --argjson t "$ids" '{solutions:[{id:"SOL-001",targets_reqs:$t,targets_risks:["RISK-001"]}]}' > "${1}/SOLUTIONS.json"
    }
    _write_sols_risks() { # <dir> <n> -> one SOL covering RISK-001..RISK-00n
        local ids; ids="$(seq -f 'RISK-%03g' 1 "$2" | jq -R . | jq -s '.')"
        jq -n --argjson t "$ids" '{solutions:[{id:"SOL-001",targets_reqs:["REQ-001"],targets_risks:$t}]}' > "${1}/SOLUTIONS.json"
    }

    _expect() { # <case-name> <expected-rc> <actual-rc>
        if [[ "$2" == "$3" ]]; then
            printf 'self-test PASS: %s (rc=%s)\n' "$1" "$3"
        else
            printf 'self-test FAIL: %s expected rc=%s got rc=%s\n' "$1" "$2" "$3" >&2
            fails=$((fails + 1))
        fi
    }

    local d rc

    # Case A: defensive, full REQ coverage, clean severities, PASS -> supported (0)
    d="${sandbox}/A"; mkdir -p "$d"
    _write_eval "$d" PASS 0 0; _write_reqs "$d" 5; _write_risks "$d" 4; _write_sols_reqs "$d" 5
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "A consistent-PASS full coverage" 0 "$rc"

    # Case B: defensive, only 2/5 REQ covered, PASS -> coverage inflation (2)
    d="${sandbox}/B"; mkdir -p "$d"
    _write_eval "$d" PASS 0 0; _write_reqs "$d" 5; _write_risks "$d" 4; _write_sols_reqs "$d" 2
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "B inflated-coverage PASS" 2 "$rc"

    # Case C: PASS but reported high=2 -> rubber-stamp / severity inconsistency (2)
    d="${sandbox}/C"; mkdir -p "$d"
    _write_eval "$d" PASS 0 2; _write_reqs "$d" 5; _write_risks "$d" 4; _write_sols_reqs "$d" 5
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "C rubber-stamp PASS with high>0" 2 "$rc"

    # Case D: NEEDS_WORK even with full coverage -> never blocked (0)
    d="${sandbox}/D"; mkdir -p "$d"
    _write_eval "$d" NEEDS_WORK 0 0; _write_reqs "$d" 5; _write_risks "$d" 4; _write_sols_reqs "$d" 5
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "D NEEDS_WORK never blocked" 0 "$rc"

    # Case E: offensive (no REQUIREMENTS.json), full RISK coverage, PASS -> supported (0)
    d="${sandbox}/E"; mkdir -p "$d"
    _write_eval "$d" PASS 0 0; _write_risks "$d" 4; _write_sols_risks "$d" 4
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "E offensive full RISK coverage PASS" 0 "$rc"

    # Case F: offensive, only 1/4 RISK covered, PASS -> coverage shortfall (2)
    d="${sandbox}/F"; mkdir -p "$d"
    _write_eval "$d" PASS 0 0; _write_risks "$d" 4; _write_sols_risks "$d" 1
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "F offensive RISK shortfall PASS" 2 "$rc"

    # Case G: PASS but no upstream artifacts to ground coverage -> unsupported (2)
    d="${sandbox}/G"; mkdir -p "$d"
    _write_eval "$d" PASS 0 0
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "G PASS with no upstream artifacts" 2 "$rc"

    # Case H: missing EVALUATION.json -> input error (1)
    d="${sandbox}/H"; mkdir -p "$d"
    rc=0; check_dir "$d" 2>/dev/null || rc=$?; _expect "H missing EVALUATION.json" 1 "$rc"

    if [[ $fails -ne 0 ]]; then
        printf 'self-test: %d case(s) FAILED\n' "$fails" >&2
        return 1
    fi
    printf 'self-test: all cases passed\n'
    return 0
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "${1:-}" in
    --self-test)
        self_test
        exit $?
        ;;
    "")
        echo "Usage: panel/check_evaluator_verdict.sh <output_dir> | --self-test" >&2
        exit 1
        ;;
    *)
        check_dir "$1"
        exit $?
        ;;
esac
