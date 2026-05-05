# Skill Auto-Invocation Map

**Purpose**: Maps system context to relevant skills for auto-discovery and load.

This document defines the canonical context-to-skill mapping used by all agents when performing reconnaissance or threat analysis. When an agent detects a target type, it loads the corresponding skill(s) before proceeding.

---

## Security Agent — Code Review Context

| Target Pattern | Skill | Description |
|---------------|-------|-------------|
| REST API, GraphQL, OpenAPI/Swagger | `api-security` | OWASP API Security Top 10:2023 |
| Web app, HTML, React, Vue, Angular | `owasp-top-10-web` | OWASP Top 10:2021 |
| IAM, OAuth, SAML, JWT, Auth | `iam-review` | NIST SP 800-63B + CIS Controls v8 |
| AWS | `aws-review` | AWS security best practices |
| Azure | `azure-review` | Azure security best practices |
| GCP | `gcp-review` | GCP security best practices |
| Docker, Kubernetes, container | `container-security` | CIS Docker/K8s benchmarks |
| Terraform, CloudFormation, IaC | `iac-security` | IaC security scanning |
| Secrets, API keys, Vault | `secrets-management` | Secrets detection and rotation |
| Dependencies (package.json, requirements.txt, Cargo.toml) | `dependency-scanning` | Known vulnerability scanning |
| CI/CD, GitHub Actions, Jenkins | `pipeline-security` | Pipeline hardening |
| SAST, linter, static scan | `sast-config` | SAST tool configuration |
| DAST, fuzzing, dynamic scan | `dast-config` | DAST tool configuration |
| LLM, RAG, prompt | `prompt-injection` | OWASP LLM01:2025 |
| AI agent, agentic system | `agent-security` | AI agent threat modeling |
| CVE, vulnerability triage | `cve-triage` | CVSS 4.0 / SSVC 2.1 / CISA KEV |
| Code (general) | `secure-code-review` | OWASP ASVS 4.0.3 + CWE Top 25 |

---

## Risk Analysis Agent — Threat Intelligence Context

| Domain | Skill | Framework |
|--------|-------|-----------|
| Web application | `owasp-top-10-web` | OWASP Top 10:2021 |
| API | `api-security` | OWASP API Security Top 10:2023 |
| Cloud (AWS/Azure/GCP) | `aws-review` / `azure-review` / `gcp-review` | CSPM benchmarks |
| Container/Kubernetes | `container-security` | CIS Benchmarks |
| IaC | `iac-security` | Policy-as-code |
| LLM/RAG | `prompt-injection` | OWASP LLM01:2025 + MITRE ATLAS |
| AI agent | `agent-security` | MITRE ATLAS |
| Network | `firewall-review` / `dns-security` | Network hardening |
| Identity | `iam-review` | NIST SP 800-63B |
| Secrets | `secrets-management` | Secrets management |
| CI/CD pipeline | `pipeline-security` | Pipeline security |
| CVE/vulnerability | `cve-triage` | CVSS 4.0 + SSVC |

---

## Solutions Agent — Implementation Context

| Vulnerability Class | Skill | Focus |
|--------------------|-------|-------|
| Injection (SQL, XSS, command) | `secure-code-review` | Input validation + encoding |
| Auth bypass | `iam-review` | MFA, session, zero trust |
| API security | `api-security` | BOLA, BFLA, rate limiting |
| Secret exposure | `secrets-management` | Rotation, Vault, env vars |
| Dependency vulnerability | `dependency-scanning` | SBOM, patching |
| Cloud misconfiguration | `aws-review` / `azure-review` / `gcp-review` | CSPM benchmarks |
| Container escape | `container-security` | Runtime security, least privilege |
| IaC misconfiguration | `iac-security` | Terraform/CloudFormation hardening |
| Pipeline compromise | `pipeline-security` | CI/CD hardening |
| Prompt injection | `prompt-injection` | Input sanitization, output filtering |
| AI agent manipulation | `agent-security` | Trust boundaries, tool access |

---

## Skill Loading Workflow

```
Target detected
      ↓
Match against SKILL_MAP (above)
      ↓
Load .claude/skills/<matched-skill>/SKILL.md
      ↓
Apply skill guidance to current task
      ↓
Proceed to analysis / advisor call
```

## Default Skill

If no pattern matches, fall back to `secure-code-review` as the default for code-centric work, or `threat-modeling` for architecture-centric work.

---

## Skill Discovery Command

```bash
# List all available skills
ls .claude/skills/*/SKILL.md | sed 's|.claude/skills/||g; s|/SKILL.md||g' | sort
```
