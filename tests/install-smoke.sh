#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/opencode-omni-memory-plugin-test.XXXXXX")"
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
  OPENCODE_OMNI_MEMORY_SOURCE="$ROOT" \
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
grep -q '<!-- opencode-omni-memory-plugin:start -->' "$CONFIG_DIR/AGENTS.md"
test -f "$CONFIG_DIR/skills/omni-memory/SKILL.md"
test -f "$CONFIG_DIR/plugins/omni-memory.js"
test -f "$CONFIG_DIR/commands/handoff.md"

# Plugin behavior: bootstrap injection is idempotent and compaction context is added.
node --input-type=module -e "
import { OmniMemoryPlugin } from '$CONFIG_DIR/plugins/omni-memory.js'
const hooks = await OmniMemoryPlugin({})
const output = { messages: [{ info: { role: 'user' }, parts: [{ type: 'text', text: 'hi' }] }] }
await hooks['experimental.chat.messages.transform']({}, output)
await hooks['experimental.chat.messages.transform']({}, output)
if (output.messages[0].parts.length !== 2) process.exit(1)
if (!output.messages[0].parts[0].text.includes('omni-memory:bootstrap')) process.exit(1)
const c = { context: [] }
await hooks['experimental.session.compacting']({ sessionID: 't' }, c)
if (c.context.length !== 1) process.exit(1)
"

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
        if (!data.includes("\"name\": \"omni-memory\"")) process.exit(1)
      })
    '
fi

printf '\n- Preserve this user memory.\n' >> "$CONFIG_DIR/memory/GLOBAL.md"
run_installer update
grep -q 'Preserve this user memory' "$CONFIG_DIR/memory/GLOBAL.md"

# Legacy migration: an old markdown-memory install must be converted in place.
mkdir -p "$CONFIG_DIR/skills/markdown-memory"
printf 'legacy skill\n' > "$CONFIG_DIR/skills/markdown-memory/SKILL.md"
node -e '
const fs = require("fs")
const path = process.argv[1]
let text = fs.readFileSync(path, "utf8")
text = text.replace("<!-- opencode-omni-memory-plugin:start -->", "<!-- opencode-markdown-memory:start -->")
text = text.replace("<!-- opencode-omni-memory-plugin:end -->", "<!-- opencode-markdown-memory:end -->")
fs.writeFileSync(path, text)
' "$CONFIG_DIR/AGENTS.md"
run_installer install
test ! -e "$CONFIG_DIR/skills/markdown-memory"
grep -q '<!-- opencode-omni-memory-plugin:start -->' "$CONFIG_DIR/AGENTS.md"
! grep -q '<!-- opencode-markdown-memory:start -->' "$CONFIG_DIR/AGENTS.md"

run_installer uninstall
grep -q 'EXISTING.md' "$CONFIG_DIR/opencode.json"
! grep -q '.opencode/project/HANDOFF.md' "$CONFIG_DIR/opencode.json"
! grep -q '<!-- opencode-omni-memory-plugin:start -->' "$CONFIG_DIR/AGENTS.md"
grep -q 'Preserve this user memory' "$CONFIG_DIR/memory/GLOBAL.md"
test ! -e "$CONFIG_DIR/skills/omni-memory"
test ! -e "$CONFIG_DIR/plugins/omni-memory.js"
test ! -e "$CONFIG_DIR/commands/handoff.md"

printf 'install smoke test: passed\n'
