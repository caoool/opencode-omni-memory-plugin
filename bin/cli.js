#!/usr/bin/env node
"use strict";

/**
 * npm entry point for opencode-omni-memory-plugin.
 *
 * Delegates to the bundled install.sh, which already resolves its own script
 * directory as the install source (the SCRIPT_DIR branch in prepare_source),
 * so running from the packaged files installs directly with no git clone.
 *
 * Usage: opencode-omni-memory-plugin [install|update|status|uninstall|help]
 */

const { spawnSync } = require("node:child_process");
const path = require("node:path");

const installer = path.join(__dirname, "..", "install.sh");
const args = process.argv.slice(2);

const result = spawnSync("bash", [installer, ...args], {
  stdio: "inherit",
  env: process.env,
});

if (result.error) {
  if (result.error.code === "ENOENT") {
    console.error(
      "[opencode-omni-memory-plugin] ERROR: 'bash' was not found on PATH. " +
        "This installer requires Bash, Git, and Node.js.",
    );
  } else {
    console.error("[opencode-omni-memory-plugin] ERROR:", result.error.message);
  }
  process.exit(1);
}

process.exit(result.status === null ? 1 : result.status);
