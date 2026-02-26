#!/usr/bin/env node

import { execSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
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

// --- Ralph dependencies ---

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

function copyRalphTemplates(targetDir) {
  copyTemplate("ralph/config.toml", targetDir, ".ralph-tui/config.toml");
  copyTemplate("ralph/settings.json", targetDir, ".claude/settings.json");
  copyTemplate("ralph/prd.json", targetDir, "prd.json");
}

function copyKiroTemplates(targetDir) {
  copyTemplate("kiro/settings/mcp.json", targetDir, ".kiro/settings/mcp.json");
  copyTemplate("kiro/steering/project.md", targetDir, ".kiro/steering/project.md");
  copyTemplate("kiro/agents/dev.json", targetDir, ".kiro/agents/dev.json");
}

// --- Usage / help ---

function printUsage() {
  log("");
  log(bold("ralph-setup") + " — scaffold Ralph TUI and/or Kiro CLI in any project");
  log("");
  log("Usage:");
  log(`  ${cyan("ralph-setup init [path]")}           Scaffold both Ralph TUI + Kiro (default)`);
  log(`  ${cyan("ralph-setup init --ralph [path]")}   Ralph TUI only`);
  log(`  ${cyan("ralph-setup init --kiro [path]")}    Kiro CLI only`);
  log("");
  log("Flags can be combined: --ralph --kiro is the same as no flags (both).");
  log("");
  log("Examples:");
  log(`  ${cyan("ralph-setup init")}                  Set up both in current directory`);
  log(`  ${cyan("ralph-setup init ./my-app")}         Set up both in ./my-app`);
  log(`  ${cyan("ralph-setup init --kiro ./my-app")}  Set up Kiro only in ./my-app`);
  log("");
}

function printNextSteps({ ralph, kiro }) {
  log("");
  log(bold("Next steps:"));
  if (ralph) {
    log(`  1. Edit ${cyan("prd.json")} with your project's user stories`);
    log(`  2. Review ${cyan(".claude/settings.json")} permissions for your needs`);
    log(`  3. Run ${cyan("ralph-tui")} to start iterating`);
  }
  if (kiro) {
    const offset = ralph ? 4 : 1;
    log(`  ${offset}. Edit ${cyan(".kiro/steering/project.md")} with your project context`);
    log(`  ${offset + 1}. Review ${cyan(".kiro/agents/dev.json")} allowed tools for your needs`);
    log(`  ${offset + 2}. Run ${cyan("kiro-cli")} to start coding`);
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

  let ralph = false;
  let kiro = false;
  let path = null;

  for (let i = 1; i < args.length; i++) {
    if (args[i] === "--ralph") {
      ralph = true;
    } else if (args[i] === "--kiro") {
      kiro = true;
    } else if (!args[i].startsWith("--")) {
      path = args[i];
    }
  }

  // Default: both when neither flag is set
  if (!ralph && !kiro) {
    ralph = true;
    kiro = true;
  }

  return { command, ralph, kiro, path };
}

// --- Main ---

const { command, ralph, kiro, path } = parseArgs(process.argv);

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

const tools = [ralph && "Ralph TUI", kiro && "Kiro CLI"].filter(Boolean).join(" + ");
log("");
log(bold(`ralph-setup init (${tools})`));
log(`  Target: ${cyan(targetDir)}`);
log("");

// --- Install dependencies ---

log(bold("Checking dependencies..."));
if (ralph) {
  ensureBun();
  ensureRalphTui();
}
if (kiro) {
  ensureKiro();
}
log("");

// --- Copy templates ---

log(bold("Copying config files..."));
if (ralph) {
  copyRalphTemplates(targetDir);
}
if (kiro) {
  copyKiroTemplates(targetDir);
}

printNextSteps({ ralph, kiro });
