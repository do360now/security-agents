---
name: security-review
description: >
  Master security review skill that orchestrates domain-specific security skills
  based on detected context. Auto-detects the target type (web app, API, cloud,
  container, LLM, etc.) and delegates to the most appropriate specialized skill
  (secure-code-review, owasp-top-10-web, api-security, prompt-injection, etc.).
  This is the top-level skill invoked by security-agents unless a more specific
  skill is identified during reconnaissance.
tags: [appsec, orchestration, master-skill]
role: [security-engineer, appsec-engineer]
phase: [build, review]
frameworks: [OWASP-ASVS, OWASP-Top-10, NIST-CSF]
difficulty: intermediate
time_estimate: "30-60min per module"
version: "1.0.0"
author: security-agents
license: MIT
allowed-tools: Read, Grep, Glob, Bash
injection-hardened: true
integrity-hash-sha256: SHA256:0d2d84e950d35653227d8d98015af94d6d5bf6bcd514109f081bb5634f391b1c
argument-hint: "[target-file-or-directory]"
---

# Security Review — Master Orchestrator Skill

This is the top-level security skill that delegates to domain-specific skills based on detected context. It is invoked by `security-agent` and `security-panel` when no specific skill matches during initial reconnaissance.

---

## Step 1: Detect Target Context

Before invoking any subskill, detect the target type:

```bash
# Quick context detection
TARGET_TYPE="unknown"

# Check for web/API patterns
if find . -type f \( -name "*.html" -o -name "*.js" -o -name "*.tsx" -o -name "*.vue" \) 2>/dev/null | head -1 | grep -q .; then
  TARGET_TYPE="web_app"
fi

# Check for API patterns
if find . -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | xargs grep -l "openapi\|swagger\|paths:" 2>/dev/null | grep -q .; then
  TARGET_TYPE="api"
fi

# Check for LLM patterns
if find . -type f \( -name "*.py" -o -name "*.js" \) 2>/dev/null | xargs grep -l "openai\|anthropic\|llm\|prompt\|chatbot" 2>/dev/null | grep -q .; then
  TARGET_TYPE="llm"
fi

# Check for cloud patterns
if find . -type f \( -name "*.tf" -o -name "*.json" \) 2>/dev/null | xargs grep -l "resource\|aws_\|azurerm_\|google_" 2>/dev/null | grep -q .; then
  TARGET_TYPE="cloud"
fi

# Check for container patterns
if find . -type f \( -name "Dockerfile" -o -name "docker-compose*" -o -name "*.dockerfile" \) 2>/dev/null | grep -q .; then
  TARGET_TYPE="container"
fi

echo "Detected target type: $TARGET_TYPE"
```

---

## Step 2: Delegate to Subskill

Based on detected context, load and apply the appropriate subskill:

| Target Type | Subskill | When to Use |
|------------|----------|-------------|
| `web_app` | `owasp-top-10-web` | Web application source code |
| `api` | `api-security` | REST/GraphQL API code or OpenAPI specs |
| `llm` | `prompt-injection` | LLM applications, RAG pipelines, chat interfaces |
| `ai_agent` | `agent-security` | AI agent implementations |
| `cloud` | `aws-review` / `azure-review` / `gcp-review` | Cloud configuration files |
| `container` | `container-security` | Dockerfiles, docker-compose, K8s configs |
| `iac` | `iac-security` | Terraform, CloudFormation, Pulumi |
| `secrets` | `secrets-management` | Code with hardcoded secrets, env files |
| `dependency` | `dependency-scanning` | package.json, requirements.txt, Cargo.toml |
| `pipeline` | `pipeline-security` | CI/CD pipeline configs (GitHub Actions, Jenkinsfile) |
| `network` | `firewall-review` / `dns-security` | Network configs, firewall rules |
| `cve` | `cve-triage` | CVE triage and prioritization |
| `code` (default) | `secure-code-review` | General code review against OWASP ASVS |

### Subskill Loading Command

```bash
SKILL_NAME="secure-code-review"  # default

case "$TARGET_TYPE" in
  web_app)    SKILL_NAME="owasp-top-10-web" ;;
  api)        SKILL_NAME="api-security" ;;
  llm)       SKILL_NAME="prompt-injection" ;;
  ai_agent)  SKILL_NAME="agent-security" ;;
  cloud)     SKILL_NAME="aws-review" ;;
  container) SKILL_NAME="container-security" ;;
  iac)       SKILL_NAME="iac-security" ;;
  secrets)   SKILL_NAME="secrets-management" ;;
  pipeline)  SKILL_NAME="pipeline-security" ;;
  network)   SKILL_NAME="firewall-review" ;;
  cve)       SKILL_NAME="cve-triage" ;;
  *)         SKILL_NAME="secure-code-review" ;;
esac

SKILL_FILE=".claude/skills/$SKILL_NAME/SKILL.md"
echo "Loading subskill: $SKILL_NAME"
```

---

## Step 3: Apply Subskill Guidance

Once the appropriate subskill is loaded:

1. **Read** the subskill's SKILL.md content
2. **Apply** the step-by-step process defined in the subskill
3. **Produce findings** mapped to the subskill's framework (OWASP, NIST, CWE, etc.)
4. **Escalate** to advisor if finding severity is ambiguous

---

## Step 4: Synthesize Report

After applying the relevant subskill(s), compile findings into a unified report:

```
## Security Review Report — [Target]

**Subskill Applied**: [name] (v[version])
**Date**: [review date]
**Target Type**: [detected context]

### Findings Summary

| Severity | Count | Primary CWE |
|----------|-------|-------------|
| Critical | [n]   | [CWE-xxx]   |
| High     | [n]   | [CWE-xxx]   |
| Medium   | [n]   | [CWE-xxx]   |
| Low      | [n]   | [CWE-xxx]   |

### Detailed Findings

[from subskill findings]

### Recommended Priority

[from subskill recommendations]
```

---

## Default Subskill

If context detection is inconclusive, default to `secure-code-review` (general code review against OWASP ASVS 4.0.3 and CWE Top 25).

---

## Skill Availability Check

```bash
# Verify all subskills are available
for skill in secure-code-review owasp-top-10-web api-security prompt-injection agent-security aws-review container-security iac-security secrets-management pipeline-security firewall-review cve-triage; do
  if [[ -f ".claude/skills/$skill/SKILL.md" ]]; then
    echo "OK: $skill"
  else
    echo "MISSING: $skill"
  fi
done
```
