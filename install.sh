#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/caoool/opencode-markdown-memory.git"
REF="${OPENCODE_MARKDOWN_MEMORY_REF:-main}"
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
DATA_ROOT="${OPENCODE_MARKDOWN_MEMORY_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/opencode-markdown-memory}"
MANAGED_REPO="$DATA_ROOT/repo"
INSTALLED_MANIFEST="$DATA_ROOT/installed-files.txt"
INSTALLED_VERSION="$DATA_ROOT/installed-version"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P || true)"
ACTION="${1:-install}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_ROOT="$DATA_ROOT/backups/$TIMESTAMP"
SOURCE_DIR=""
CONFIG_FILE=""

usage() {
  cat <<'EOF'
Usage: install.sh [install|update|status|uninstall|help]

Commands:
  install    Install the skill, commands, instructions, and missing memory files.
  update     Pull the configured Git ref and reinstall managed files.
  status     Report installed version and integration health.
  uninstall Remove managed skill/command/instruction wiring; preserve memory data.
  help       Show this message.

Environment:
  OPENCODE_CONFIG_DIR              Override ~/.config/opencode.
  OPENCODE_MARKDOWN_MEMORY_HOME    Override updater data/checkout location.
  OPENCODE_MARKDOWN_MEMORY_REF     Git branch or ref to install (default: main).
  OPENCODE_MARKDOWN_MEMORY_SOURCE  Use a local source checkout (development/testing).
  OPENCODE_MEMORY_HOSTNAME         Override the generated host-memory filename.
EOF
}

log() {
  printf '[opencode-markdown-memory] %s\n' "$*"
}

die() {
  printf '[opencode-markdown-memory] ERROR: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

prepare_source() {
  need git
  need node

  if [[ -n "${OPENCODE_MARKDOWN_MEMORY_SOURCE:-}" ]]; then
    SOURCE_DIR="$OPENCODE_MARKDOWN_MEMORY_SOURCE"
  elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/VERSION" && -d "$SCRIPT_DIR/skills/markdown-memory" ]]; then
    SOURCE_DIR="$SCRIPT_DIR"
  else
    SOURCE_DIR="$MANAGED_REPO"
    if [[ ! -d "$SOURCE_DIR/.git" ]]; then
      mkdir -p "$DATA_ROOT"
      log "Cloning $REPO_URL at $REF"
      git clone --depth 1 --branch "$REF" "$REPO_URL" "$SOURCE_DIR"
    fi
  fi

  [[ -f "$SOURCE_DIR/VERSION" ]] || die "Invalid source: VERSION is missing from $SOURCE_DIR"
  [[ -f "$SOURCE_DIR/manifest.txt" ]] || die "Invalid source: manifest.txt is missing from $SOURCE_DIR"
  [[ -d "$SOURCE_DIR/skills/markdown-memory" ]] || die "Invalid source: markdown-memory skill is missing"

  if [[ "$ACTION" == "update" && -z "${OPENCODE_MARKDOWN_MEMORY_SOURCE:-}" ]]; then
    [[ -d "$SOURCE_DIR/.git" ]] || die "Update requires a Git checkout: $SOURCE_DIR"
    log "Updating $SOURCE_DIR from $REF"
    git -C "$SOURCE_DIR" fetch origin "$REF"
    git -C "$SOURCE_DIR" merge --ff-only FETCH_HEAD
  fi
}

choose_config_file() {
  mkdir -p "$CONFIG_DIR"
  if [[ -e "$CONFIG_DIR/opencode.json" ]]; then
    CONFIG_FILE="$CONFIG_DIR/opencode.json"
  elif [[ -e "$CONFIG_DIR/opencode.jsonc" ]]; then
    CONFIG_FILE="$CONFIG_DIR/opencode.jsonc"
  else
    CONFIG_FILE="$CONFIG_DIR/opencode.json"
  fi

  if [[ -e "$CONFIG_FILE" ]]; then
    if ! node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$CONFIG_FILE" >/dev/null 2>&1; then
      die "$CONFIG_FILE contains JSONC comments or otherwise is not strict JSON. Add the three documented instructions manually, or provide a strict opencode.json, then rerun."
    fi
  fi
}

global_memory_instruction() {
  local path="$CONFIG_DIR/memory/GLOBAL.md"
  case "$path" in
    "$HOME"/*) printf '~/%s' "${path#"$HOME"/}" ;;
    *) printf '%s' "$path" ;;
  esac
}

backup_path() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  local rel="${path#"$CONFIG_DIR"/}"
  local target="$BACKUP_ROOT/$rel"
  mkdir -p "$(dirname -- "$target")"
  cp -R -- "$path" "$target"
  log "Backed up $path to $target"
}

paths_differ() {
  local source="$1"
  local target="$2"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return 0
  fi
  if [[ -d "$source" ]]; then
    ! diff -qr -- "$source" "$target" >/dev/null 2>&1
  else
    ! cmp -s -- "$source" "$target"
  fi
}

install_managed_path() {
  local rel="$1"
  local source="$SOURCE_DIR/$rel"
  local target="$CONFIG_DIR/$rel"
  [[ -e "$source" ]] || die "Manifest source is missing: $source"

  if ! paths_differ "$source" "$target"; then
    return 0
  fi

  backup_path "$target"
  mkdir -p "$(dirname -- "$target")"
  if [[ -d "$source" ]]; then
    local staging="${target}.tmp.$$"
    rm -rf -- "$staging"
    cp -R -- "$source" "$staging"
    rm -rf -- "$target"
    mv -- "$staging" "$target"
  else
    cp -- "$source" "$target"
  fi
  log "Installed $rel"
}

install_default_file() {
  local source="$1"
  local target="$2"
  if [[ -e "$target" ]]; then
    return 0
  fi
  mkdir -p "$(dirname -- "$target")"
  cp -- "$source" "$target"
  log "Created $target"
}

install_host_file() {
  local hostname="${OPENCODE_MEMORY_HOSTNAME:-${HOSTNAME:-$(uname -n)}}"
  local target="$CONFIG_DIR/memory/hosts/$hostname.md"
  [[ -e "$target" ]] && return 0
  mkdir -p "$(dirname -- "$target")"
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s\n' "${line//__HOSTNAME__/$hostname}"
  done < "$SOURCE_DIR/defaults/memory/HOST.md" > "$target"
  log "Created $target"
}

render_config() {
  local mode="$1"
  local output="$2"
  local global_instruction
  global_instruction="$(global_memory_instruction)"
  node - "$CONFIG_FILE" "$output" "$mode" "$global_instruction" <<'NODE'
const fs = require("fs")
const [input, output, mode, globalInstruction] = process.argv.slice(2)
const wanted = [
  globalInstruction,
  ".opencode/project/MEMORY.md",
  ".opencode/project/HANDOFF.md",
]
const original = fs.existsSync(input) ? fs.readFileSync(input, "utf8") : ""
let config = { $schema: "https://opencode.ai/config.json" }
if (original) config = JSON.parse(original)
const before = JSON.stringify(config)
const current = Array.isArray(config.instructions) ? config.instructions : []
if (mode === "install") {
  config.instructions = [...new Set([...current, ...wanted])]
} else {
  const removable = new Set([...wanted, "~/.config/opencode/memory/GLOBAL.md"])
  const next = current.filter((item) => !removable.has(item))
  if (next.length) config.instructions = next
  else delete config.instructions
}
const rendered = JSON.stringify(config) === before && original
  ? original
  : JSON.stringify(config, null, 2) + "\n"
fs.writeFileSync(output, rendered)
NODE
}

patch_config() {
  local mode="$1"
  choose_config_file
  local output="${CONFIG_FILE}.tmp.$$"
  render_config "$mode" "$output"
  if [[ -e "$CONFIG_FILE" ]] && cmp -s -- "$CONFIG_FILE" "$output"; then
    rm -f -- "$output"
    return 0
  fi
  backup_path "$CONFIG_FILE"
  mv -- "$output" "$CONFIG_FILE"
  log "Updated $CONFIG_FILE"
}

render_agents() {
  local mode="$1"
  local agents="$CONFIG_DIR/AGENTS.md"
  local output="${agents}.tmp.$$"
  local snippet="$SOURCE_DIR/snippets/AGENTS.md"
  node - "$agents" "$snippet" "$output" "$mode" <<'NODE'
const fs = require("fs")
const [agentsPath, snippetPath, output, mode] = process.argv.slice(2)
const start = "<!-- opencode-markdown-memory:start -->"
const end = "<!-- opencode-markdown-memory:end -->"
let text = fs.existsSync(agentsPath) ? fs.readFileSync(agentsPath, "utf8") : ""
const startIndex = text.indexOf(start)
const endIndex = text.indexOf(end)
if ((startIndex === -1) !== (endIndex === -1) || (startIndex !== -1 && endIndex < startIndex)) {
  throw new Error("AGENTS.md contains an incomplete opencode-markdown-memory managed block")
}
if (mode === "install") {
  const snippet = fs.readFileSync(snippetPath, "utf8").trim()
  if (startIndex !== -1) {
    const after = endIndex + end.length
    const existing = text.slice(startIndex, after).trim()
    if (existing === snippet) {
      fs.writeFileSync(output, text)
      process.exit(0)
    }
    text = text.slice(0, startIndex) + snippet + text.slice(after)
  } else {
    text = text.trimEnd()
    text = (text ? text + "\n\n" : "") + snippet + "\n"
  }
} else {
  if (startIndex !== -1) {
    const after = endIndex + end.length
    text = text.slice(0, startIndex).trimEnd() + text.slice(after)
    text = text.replace(/^\s+/, "")
  }
  text = text.trim()
  text = text ? text + "\n" : ""
}
fs.writeFileSync(output, text)
NODE

  if [[ -e "$agents" ]] && cmp -s -- "$agents" "$output"; then
    rm -f -- "$output"
    return 0
  fi
  backup_path "$agents"
  mv -- "$output" "$agents"
  log "Updated $agents"
}

install_payload() {
  choose_config_file
  mkdir -p "$DATA_ROOT"

  while IFS= read -r rel || [[ -n "$rel" ]]; do
    [[ -z "$rel" || "$rel" == \#* ]] && continue
    install_managed_path "$rel"
  done < "$SOURCE_DIR/manifest.txt"

  install_default_file "$SOURCE_DIR/defaults/memory/GLOBAL.md" "$CONFIG_DIR/memory/GLOBAL.md"
  install_default_file "$SOURCE_DIR/defaults/memory/HANDOFF.md" "$CONFIG_DIR/memory/HANDOFF.md"
  install_default_file "$SOURCE_DIR/defaults/memory/archive/README.md" "$CONFIG_DIR/memory/archive/README.md"
  install_host_file
  patch_config install
  render_agents install

  cp -- "$SOURCE_DIR/manifest.txt" "$INSTALLED_MANIFEST"
  cp -- "$SOURCE_DIR/VERSION" "$INSTALLED_VERSION"
  log "Installed version $(<"$SOURCE_DIR/VERSION")"
  log "Restart OpenCode to load configuration-time changes."
}

remove_managed_paths() {
  local manifest="$INSTALLED_MANIFEST"
  if [[ ! -f "$manifest" ]]; then
    [[ -n "$SOURCE_DIR" && -f "$SOURCE_DIR/manifest.txt" ]] || die "No installed manifest found"
    manifest="$SOURCE_DIR/manifest.txt"
  fi

  while IFS= read -r rel || [[ -n "$rel" ]]; do
    [[ -z "$rel" || "$rel" == \#* ]] && continue
    local target="$CONFIG_DIR/$rel"
    case "$target" in
      "$CONFIG_DIR"/*) ;;
      *) die "Unsafe uninstall path: $target" ;;
    esac
    if [[ -d "$target" ]]; then rm -rf -- "$target"; else rm -f -- "$target"; fi
    log "Removed $rel"
  done < "$manifest"
}

status() {
  local version="not installed"
  [[ -f "$INSTALLED_VERSION" ]] && version="$(<"$INSTALLED_VERSION")"
  printf 'Version: %s\n' "$version"
  printf 'Config: %s\n' "$CONFIG_DIR"

  local missing=0
  local manifest="$INSTALLED_MANIFEST"
  if [[ ! -f "$manifest" && -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/manifest.txt" ]]; then
    manifest="$SCRIPT_DIR/manifest.txt"
  fi
  if [[ -f "$manifest" ]]; then
    while IFS= read -r rel || [[ -n "$rel" ]]; do
      [[ -z "$rel" || "$rel" == \#* ]] && continue
      if [[ ! -e "$CONFIG_DIR/$rel" ]]; then
        printf 'Missing: %s\n' "$rel"
        missing=$((missing + 1))
      fi
    done < "$manifest"
  else
    printf 'Missing: installation manifest\n'
    missing=$((missing + 1))
  fi

  [[ -f "$CONFIG_DIR/memory/GLOBAL.md" ]] || { printf 'Missing: memory/GLOBAL.md\n'; missing=$((missing + 1)); }
  [[ -f "$CONFIG_DIR/memory/HANDOFF.md" ]] || { printf 'Missing: memory/HANDOFF.md\n'; missing=$((missing + 1)); }

  local config_path=""
  if [[ -f "$CONFIG_DIR/opencode.json" ]]; then
    config_path="$CONFIG_DIR/opencode.json"
  elif [[ -f "$CONFIG_DIR/opencode.jsonc" ]]; then
    config_path="$CONFIG_DIR/opencode.jsonc"
  fi
  local global_instruction
  global_instruction="$(global_memory_instruction)"
  if [[ -n "$config_path" ]] && node -e '
    const fs = require("fs")
    const [path, globalInstruction] = process.argv.slice(1)
    const config = JSON.parse(fs.readFileSync(path, "utf8"))
    const instructions = Array.isArray(config.instructions) ? config.instructions : []
    const wanted = [globalInstruction, ".opencode/project/MEMORY.md", ".opencode/project/HANDOFF.md"]
    if (!wanted.every((item) => instructions.includes(item))) process.exit(1)
  ' "$config_path" "$global_instruction" >/dev/null 2>&1; then
    printf 'Config instructions: present\n'
  else
    printf 'Config instructions: missing or unreadable\n'
    missing=$((missing + 1))
  fi
  if [[ -f "$CONFIG_DIR/AGENTS.md" ]] && grep -q '<!-- opencode-markdown-memory:start -->' "$CONFIG_DIR/AGENTS.md"; then
    printf 'AGENTS.md integration: present\n'
  else
    printf 'AGENTS.md integration: missing\n'
    missing=$((missing + 1))
  fi

  if (( missing == 0 )); then
    printf 'Status: healthy\n'
  else
    printf 'Status: incomplete (%d issue(s))\n' "$missing"
    return 1
  fi
}

uninstall() {
  need node
  choose_config_file
  remove_managed_paths
  patch_config uninstall
  if [[ -n "$SOURCE_DIR" && -f "$SOURCE_DIR/snippets/AGENTS.md" ]]; then
    render_agents uninstall
  elif [[ -f "$CONFIG_DIR/AGENTS.md" ]]; then
    local placeholder="$DATA_ROOT/uninstall-source/snippets"
    mkdir -p "$placeholder"
    : > "$placeholder/AGENTS.md"
    SOURCE_DIR="$DATA_ROOT/uninstall-source"
    render_agents uninstall
    rm -rf -- "$DATA_ROOT/uninstall-source"
  fi
  rm -f -- "$INSTALLED_MANIFEST" "$INSTALLED_VERSION"
  log "Uninstalled managed skill, commands, and instruction wiring."
  log "Preserved memory data under $CONFIG_DIR/memory and project .opencode/project directories."
  log "Restart OpenCode to unload configuration-time changes."
}

case "$ACTION" in
  install)
    prepare_source
    install_payload
    ;;
  update)
    prepare_source
    install_payload
    ;;
  status)
    status
    ;;
  uninstall)
    if [[ -n "${OPENCODE_MARKDOWN_MEMORY_SOURCE:-}" ]]; then SOURCE_DIR="$OPENCODE_MARKDOWN_MEMORY_SOURCE"; fi
    if [[ -z "$SOURCE_DIR" && -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/snippets/AGENTS.md" ]]; then SOURCE_DIR="$SCRIPT_DIR"; fi
    uninstall
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    die "Unknown command: $ACTION"
    ;;
esac
