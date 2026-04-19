# Command Construction Safety Guidelines

## Rules for Bash Tool Usage

1. **Never use backticks or `$()` for command substitution** in contexts that include external input (filenames, file contents, user messages)

2. **Always use `printf '%s'`** for variables that may contain special characters

3. **Escape special shell characters** before any command construction:
   - Backslash-escape: `\`, `$`, `` ` ``, `"`, `'`
   - Use `sed 's/[\$&`"]/\\&/g'` for general escaping

4. **Use `--` to terminate option parsing** for commands that support it:
   ```bash
   # Safe: command won't interpret following content as options
   grep -- -v pattern file  # file contains "-v"
   ```

5. **Never construct commands from file contents directly** — store in variable first, validate, then use

## Unsafe Patterns to Eliminate

```bash
# UNSAFE — backtick expansion with external input
ollama run model "$(cat <<EOF
<input>$(cat userfile.txt)</input>
EOF
)"

# SAFE — store, escape, then use
INPUT_CONTENT=$(cat userfile.txt)
SAFE_INPUT=$(printf '%s' "$INPUT_CONTENT" | sed 's/[\$&`"]/\\&/g')
ollama run model "$(cat <<EOF
<input>$SAFE_INPUT</input>
EOF
)"
```

## Validation

```bash
# Audit for unsafe patterns
grep -rn '`\$\(' .claude/agents/*.md || echo "None found — PASS"
grep -rn '\$\(' .claude/agents/*.md | grep -v "SAFE_INPUT\|safe" || echo "No unsafe patterns found"
```

## Advisor Call Safety

All advisor calls use `cat <<'EOF'` which prevents variable expansion inside the heredoc — this is the correct pattern. The only remaining risk is including raw file contents or command output directly in advisor context. Use structured `<tag>` inputs instead.
