#!/usr/bin/env node

import { execSync } from "node:child_process";
import { chmodSync, copyFileSync, existsSync, mkdirSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const TEMPLATES_DIR = join(__dirname, "..", "templates");

// ANSI colors
const bold = (s) => `\x1b[1m${s}\x1b[0m`;
const green = (s) => `\x1b[32m${s}\x1b[0m`;
const yellow = (s) => `\x1b[33m${s}\x1b[0m`;
const red = (s) => `\x1b[31m${s}\x1b[0m`;
const cyan = (s) => `\x1b[36m${s}\x1b[0m`;

function log(msg) {
  console.log(msg);
}

function success(msg) {
  log(green(`  ✓ ${msg}`));
}

function warn(msg) {
  log(yellow(`  ⚠ ${msg}`));
}

function error(msg) {
  log(red(`  ✗ ${msg}`));
}

const BUN_BIN = join(homedir(), ".bun", "bin");

function execWithBunPath(cmd, opts = {}) {
  const PATH = `${BUN_BIN}:${process.env.PATH}`;
  return execSync(cmd, { ...opts, env: { ...process.env, PATH } });
}

function commandExists(cmd) {
  try {
    execWithBunPath(`which ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

// --- Claude Code dependencies ---

function ensureBun() {
  if (commandExists("bun")) {
    success("Bun is already installed");
    return;
  }

  log("  Installing Bun...");
  try {
    execSync("curl -fsSL https://bun.sh/install | bash", {
      stdio: "inherit",
    });
    success("Bun installed");
  } catch (e) {
    error("Failed to install Bun. Install manually: https://bun.sh");
    process.exit(1);
  }
}

function ensureRalphTui() {
  if (commandExists("ralph-tui")) {
    success("ralph-tui is already installed");
    return;
  }

  log("  Installing ralph-tui...");
  try {
    execWithBunPath("bun install -g ralph-tui", { stdio: "inherit" });
    success("ralph-tui installed");
  } catch (e) {
    error("Failed to install ralph-tui. Run manually: bun install -g ralph-tui");
    process.exit(1);
  }
}

// --- Kiro dependencies ---

function ensureKiro() {
  if (commandExists("kiro-cli")) {
    success("Kiro CLI is already installed");
    return;
  }

  log("  Installing Kiro CLI...");
  try {
    execSync("curl -fsSL https://cli.kiro.dev/install | bash", {
      stdio: "inherit",
    });
    success("Kiro CLI installed");
  } catch (e) {
    error("Failed to install Kiro CLI. Install manually: https://cli.kiro.dev");
    process.exit(1);
  }
}

// --- Template copying ---

function copyTemplate(srcRelPath, destDir, destRelPath) {
  const src = join(TEMPLATES_DIR, srcRelPath);
  const dest = join(destDir, destRelPath);
  const destParent = dirname(dest);

  if (!existsSync(destParent)) {
    mkdirSync(destParent, { recursive: true });
  }

  if (existsSync(dest)) {
    warn(`${destRelPath} already exists — skipping`);
    return;
  }

  copyFileSync(src, dest);
  success(`Created ${destRelPath}`);
}

function copyClaudeTemplates(targetDir) {
  copyTemplate("claude/config.toml", targetDir, ".ralph-tui/config.toml");
  copyTemplate("claude/settings.json", targetDir, ".claude/settings.json");
  copyTemplate("claude/prd.json", targetDir, "prd.json");
}

function copyKiroTemplates(targetDir) {
  copyTemplate("kiro/settings/mcp.json", targetDir, ".kiro/settings/mcp.json");
  copyTemplate("kiro/steering/project.md", targetDir, ".kiro/steering/project.md");
  copyTemplate("kiro/agents/dev.json", targetDir, ".kiro/agents/dev.json");

  // Shell scripts for latency reduction and security enforcement
  const scripts = [
    "setup-project.sh",
    "run-tests.sh",
    "validate-acceptance.sh",
    "safe-git.sh",
    "scan-secrets.sh",
    "check-build.sh",
  ];

  for (const script of scripts) {
    copyTemplate(`kiro/scripts/${script}`, targetDir, `.kiro/scripts/${script}`);
  }

  // Ensure scripts are executable
  const scriptsDir = join(targetDir, ".kiro", "scripts");
  if (existsSync(scriptsDir)) {
    for (const f of readdirSync(scriptsDir)) {
      if (f.endsWith(".sh")) {
        chmodSync(join(scriptsDir, f), 0o755);
      }
    }
  }
}

// --- Usage / help ---

function printUsage() {
  log("");
  log(bold("ralph-setup") + " — scaffold Claude Code and/or Kiro CLI configs for Ralph TUI");
  log("");
  log("Usage:");
  log(`  ${cyan("ralph-setup init [path]")}            Scaffold both Claude Code + Kiro (default)`);
  log(`  ${cyan("ralph-setup init --claude [path]")}   Claude Code only`);
  log(`  ${cyan("ralph-setup init --kiro [path]")}     Kiro CLI only`);
  log("");
  log("Flags can be combined: --claude --kiro is the same as no flags (both).");
  log("");
  log("Examples:");
  log(`  ${cyan("ralph-setup init")}                   Set up both in current directory`);
  log(`  ${cyan("ralph-setup init ./my-app")}          Set up both in ./my-app`);
  log(`  ${cyan("ralph-setup init --kiro ./my-app")}   Set up Kiro only in ./my-app`);
  log("");
}

function printNextSteps({ claude, kiro }) {
  log("");
  log(bold("Next steps:"));
  if (claude) {
    log(`  1. Edit ${cyan("prd.json")} with your project's user stories`);
    log(`  2. Review ${cyan(".claude/settings.json")} permissions for your needs`);
    log(`  3. Run ${cyan("ralph-tui")} to start iterating`);
  }
  if (kiro) {
    const offset = claude ? 4 : 1;
    log(`  ${offset}. Edit ${cyan(".kiro/steering/project.md")} with your project context`);
    log(`  ${offset + 1}. Review ${cyan(".kiro/agents/dev.json")} allowed tools for your needs`);
    log(`  ${offset + 2}. Review ${cyan(".kiro/scripts/")} shell helpers (safe-git, scan-secrets, etc.)`);
    log(`  ${offset + 3}. Run ${cyan("kiro-cli")} to start coding`);
  }
  log("");
}

// --- Arg parsing ---

function parseArgs(argv) {
  const args = argv.slice(2);
  const command = args[0];

  if (!command || command.startsWith("--")) {
    return { command: null };
  }

  let claude = false;
  let kiro = false;
  let path = null;

  for (let i = 1; i < args.length; i++) {
    if (args[i] === "--claude") {
      claude = true;
    } else if (args[i] === "--kiro") {
      kiro = true;
    } else if (!args[i].startsWith("--")) {
      path = args[i];
    }
  }

  // Default: both when neither flag is set
  if (!claude && !kiro) {
    claude = true;
    kiro = true;
  }

  return { command, claude, kiro, path };
}

// --- Main ---

const { command, claude, kiro, path } = parseArgs(process.argv);

if (!command) {
  printUsage();
  process.exit(0);
}

if (command !== "init") {
  error(`Unknown command: ${command}`);
  printUsage();
  process.exit(1);
}

const targetDir = resolve(path || ".");

const tools = [claude && "Claude Code", kiro && "Kiro CLI"].filter(Boolean).join(" + ");
log("");
log(bold(`ralph-setup init (${tools})`));
log(`  Target: ${cyan(targetDir)}`);
log("");

// --- Install dependencies ---

log(bold("Checking dependencies..."));
if (claude) {
  ensureBun();
  ensureRalphTui();
}
if (kiro) {
  ensureKiro();
}
log("");

// --- Copy templates ---

log(bold("Copying config files..."));
if (claude) {
  copyClaudeTemplates(targetDir);
}
if (kiro) {
  copyKiroTemplates(targetDir);
}

printNextSteps({ claude, kiro });
