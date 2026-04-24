# Skill Version Pinning Policy

**Compliance**:
- **EU AI Act**: Full requirements take effect **August 2, 2026** — requires documented adversarial testing for high-risk AI systems. Skills used in security-critical agents should be version-pinned to support audit trails.
- **NIST AI RMF**: Recommends continuous adversarial testing throughout AI lifecycle; version pinning supports reproducibility of test results.

**Purpose**: Prevent supply chain attacks via compromised skill registries.

**Policy**:
- All skills must pin to an exact version or commit hash
- No floating versions (`latest`, `*`, `>=1.0`)
- When adding a skill, verify the version exists in the registry before adding

**Adding a New Skill**:
```bash
# Verify skill version exists
claude skill list | grep <skill-name>
# Add to agent YAML with exact version
skills:
  - name: security-review
    version: v1.0.0  # or commit hash
```

**Verification**:
```bash
# Check all agent YAMLs for floating versions
./verify-skill-versions.sh
```
