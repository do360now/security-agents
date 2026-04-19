# How to Run the Red-Team Test Suite

Different ways to run the 22 security tests.

## Quick Summary

```bash
./setup-and-redteam.sh
```

Shows pass/fail per test with a one-line summary.

## Verbose Output

```bash
make red-team-full
```

Shows detailed output for each test category.

## Individual Test Scripts

Run specific verification scripts directly:

```bash
# Agent integrity hashes
./verify-all-agents.sh

# Model allowlist
./validate-makefile-models.sh

# Advisor output validation
./validate-advisor-output.sh

# Config drift detection
./detect-config-drift.sh

# Command substitution check
./pre-commit-inline-script-check.sh

# Skill version pinning
./verify-skill-versions.sh
```

## CI/CD Integration

Add to your CI pipeline:

```bash
./setup-and-redteam.sh
```

The script exits 0 on all-pass, 1 on any failure. RT-013 (audit logging) may warn if infrastructure is not configured — this is informational.

## Pre-Commit Hook

To run tests before every commit, set up the pre-commit hook:

```bash
cp setup-and-redteam.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Or copy individual checks:

```bash
cp pre-commit-inline-script-check.sh .git/hooks/pre-commit
```
