#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/opencode-markdown-memory-test.XXXXXX")"
trap 'rm -rf -- "$TEST_HOME"' EXIT

CONFIG_DIR="$TEST_HOME/.config/opencode"
DATA_DIR="$TEST_HOME/.local/share"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "share": "manual",
  "instructions": ["EXISTING.md"]
}
JSON

cat > "$CONFIG_DIR/AGENTS.md" <<'MARKDOWN'
# Existing Instructions

Preserve this content.
MARKDOWN

run_installer() {
  HOME="$TEST_HOME" \
  XDG_CONFIG_HOME="$TEST_HOME/.config" \
  XDG_DATA_HOME="$DATA_DIR" \
  OPENCODE_MARKDOWN_MEMORY_SOURCE="$ROOT" \
  "$ROOT/install.sh" "$@"
}

run_status() {
  HOME="$TEST_HOME" \
  XDG_CONFIG_HOME="$TEST_HOME/.config" \
  XDG_DATA_HOME="$DATA_DIR" \
  "$ROOT/install.sh" status
}

run_installer install
run_installer install
run_status

grep -q 'EXISTING.md' "$CONFIG_DIR/opencode.json"
grep -q '.opencode/project/HANDOFF.md' "$CONFIG_DIR/opencode.json"
grep -q '<!-- opencode-markdown-memory:start -->' "$CONFIG_DIR/AGENTS.md"
test -f "$CONFIG_DIR/skills/markdown-memory/SKILL.md"
test -f "$CONFIG_DIR/commands/handoff.md"

if command -v opencode >/dev/null 2>&1; then
  HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" XDG_DATA_HOME="$DATA_DIR" \
    opencode debug config | node -e '
      let data = ""
      process.stdin.on("data", (chunk) => data += chunk)
      process.stdin.on("end", () => {
        const config = JSON.parse(data)
        const commands = Object.keys(config.command || {})
        if (!commands.includes("handoff") || !commands.includes("memory-audit")) process.exit(1)
      })
    '
  HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" XDG_DATA_HOME="$DATA_DIR" \
    opencode debug skill | node -e '
      let data = ""
      process.stdin.on("data", (chunk) => data += chunk)
      process.stdin.on("end", () => {
        if (!data.includes("\"name\": \"markdown-memory\"")) process.exit(1)
      })
    '
fi

printf '\n- Preserve this user memory.\n' >> "$CONFIG_DIR/memory/GLOBAL.md"
run_installer update
grep -q 'Preserve this user memory' "$CONFIG_DIR/memory/GLOBAL.md"

run_installer uninstall
grep -q 'EXISTING.md' "$CONFIG_DIR/opencode.json"
! grep -q '.opencode/project/HANDOFF.md' "$CONFIG_DIR/opencode.json"
! grep -q '<!-- opencode-markdown-memory:start -->' "$CONFIG_DIR/AGENTS.md"
grep -q 'Preserve this user memory' "$CONFIG_DIR/memory/GLOBAL.md"
test ! -e "$CONFIG_DIR/skills/markdown-memory"
test ! -e "$CONFIG_DIR/commands/handoff.md"

printf 'install smoke test: passed\n'
