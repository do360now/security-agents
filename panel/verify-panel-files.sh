#!/usr/bin/env bash
# panel/verify-panel-files.sh — Verify panel schema and system-prompt file integrity
#
# Usage:
#   panel/verify-panel-files.sh           # verify against manifest
#   panel/verify-panel-files.sh --update  # regenerate manifest
#   panel/verify-panel-files.sh --self-test  # run sandbox self-test
#
# Exit codes:
#   0 — all files match manifest
#   1 — mismatch found (or manifest missing in default mode)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${REPO_ROOT}/panel/file-manifest.sha256"

# ---------------------------------------------------------------------------
# --self-test mode
# ---------------------------------------------------------------------------
self_test() {
    local SANDBOX
    SANDBOX="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${SANDBOX}'" EXIT

    # Create fake manifest and matching files
    mkdir -p "${SANDBOX}/panel/schemas" "${SANDBOX}/panel/system-prompts"
    printf 'hello schema\n' > "${SANDBOX}/panel/schemas/fake.schema.json"
    printf 'hello prompt\n' > "${SANDBOX}/panel/system-prompts/fake.md"

    local hash_schema hash_prompt
    hash_schema="$(sha256sum "${SANDBOX}/panel/schemas/fake.schema.json" | cut -d' ' -f1)"
    hash_prompt="$(sha256sum "${SANDBOX}/panel/system-prompts/fake.md" | cut -d' ' -f1)"

    # Write manifest using relative paths (matching the format)
    printf '%s  panel/schemas/fake.schema.json\n' "$hash_schema" > "${SANDBOX}/panel/file-manifest.sha256"
    printf '%s  panel/system-prompts/fake.md\n' "$hash_prompt" >> "${SANDBOX}/panel/file-manifest.sha256"

    # Test 1: should pass (files match manifest)
    local exit1=0
    MANIFEST="${SANDBOX}/panel/file-manifest.sha256" REPO_ROOT_OVERRIDE="${SANDBOX}" \
        verify_against_manifest || exit1=$?

    if [[ $exit1 -ne 0 ]]; then
        printf 'SELF-TEST FAIL: expected exit 0 on matching files, got %d\n' "$exit1" >&2
        exit 1
    fi
    printf 'Self-test pass: matching files exit 0\n'

    # Test 2: mutate a file, should fail
    printf 'MUTATED\n' >> "${SANDBOX}/panel/schemas/fake.schema.json"

    local exit2=0
    MANIFEST="${SANDBOX}/panel/file-manifest.sha256" REPO_ROOT_OVERRIDE="${SANDBOX}" \
        verify_against_manifest 2>/dev/null || exit2=$?

    if [[ $exit2 -ne 1 ]]; then
        printf 'SELF-TEST FAIL: expected exit 1 on mutated file, got %d\n' "$exit2" >&2
        exit 1
    fi
    printf 'Self-test pass: mutated file exits 1\n'

    printf 'Self-test complete: all cases passed\n'
    return 0
}

# ---------------------------------------------------------------------------
# verify_against_manifest — core verification logic
# Reads MANIFEST and REPO_ROOT_OVERRIDE (if set) or REPO_ROOT
# ---------------------------------------------------------------------------
verify_against_manifest() {
    local manifest="${MANIFEST}"
    local root="${REPO_ROOT_OVERRIDE:-${REPO_ROOT}}"

    if [[ ! -f "$manifest" ]]; then
        printf 'ERROR: manifest not found: %s\n' "$manifest" >&2
        return 1
    fi

    local any_fail=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip blank lines
        [[ -z "$line" ]] && continue

        # Parse: "<hash>  <relative-path>"
        local expected_hash rel_path
        expected_hash="$(printf '%s' "$line" | awk '{print $1}')"
        rel_path="$(printf '%s' "$line" | awk '{print $2}')"

        local abs_path="${root}/${rel_path}"

        if [[ ! -f "$abs_path" ]]; then
            printf 'MISSING: %s\n' "$rel_path" >&2
            any_fail=1
            continue
        fi

        local actual_hash
        actual_hash="$(sha256sum "$abs_path" | cut -d' ' -f1)"

        if [[ "$actual_hash" != "$expected_hash" ]]; then
            printf 'MISMATCH: %s\n' "$rel_path" >&2
            printf '  expected: %s\n' "$expected_hash" >&2
            printf '  actual:   %s\n' "$actual_hash" >&2
            any_fail=1
            # Exit on first mismatch (spec says "exit 0 if all match, 1 on first mismatch")
            return 1
        fi
    done < "$manifest"

    if [[ $any_fail -ne 0 ]]; then
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# --update mode
# ---------------------------------------------------------------------------
update_manifest() {
    local out="${MANIFEST}"
    sha256sum \
        "${REPO_ROOT}/panel/schemas/"*.json \
        "${REPO_ROOT}/panel/system-prompts/"*.md \
        | sed "s|${REPO_ROOT}/||g" > "$out"
    printf 'Updated: %s\n' "$out"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "${1:-}" in
    --self-test)
        self_test
        exit 0
        ;;
    --update)
        update_manifest
        exit 0
        ;;
    "")
        verify_against_manifest
        exit $?
        ;;
    *)
        printf 'Usage: panel/verify-panel-files.sh [--update|--self-test]\n' >&2
        exit 1
        ;;
esac
