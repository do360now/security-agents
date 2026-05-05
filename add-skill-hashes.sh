#!/usr/bin/env bash
set -euo pipefail

SKILLS_DIR="/home/cmc/git/security-agents/.claude/skills"

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="${skill_dir}SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    echo "SKIP: $skill_name (no SKILL.md)"
    continue
  fi

  if grep -q 'integrity-hash-sha256:' "$skill_file"; then
    echo "SKIP: $skill_name (already has hash)"
    continue
  fi

  FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')
  COMPUTED=$(printf '%s' "$FRONTMATTER" | grep -v 'integrity-hash-sha256:' | sha256sum | awk '{print $1}')

  sed -i "s/^injection-hardened: true/injection-hardened: true\nintegrity-hash-sha256: SHA256:$COMPUTED/" "$skill_file"

  echo "HASH: $skill_name"
done
