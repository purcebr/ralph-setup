#!/usr/bin/env bash
set -euo pipefail

# setup-project.sh — Detect package manager, install deps, and run build.
# Batches multiple operations into one shell call to reduce Kiro CLI latency.

START_TIME=$SECONDS

# --- Detect package manager ---

detect_pm() {
  if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
    echo "bun"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "yarn.lock" ]; then
    echo "yarn"
  elif [ -f "package-lock.json" ]; then
    echo "npm"
  else
    echo "npm"
  fi
}

PM=$(detect_pm)
echo "[INFO] Detected package manager: $PM"

# --- Install dependencies ---

echo "[INFO] Installing dependencies..."
if $PM install; then
  echo "[PASS] Dependencies installed"
else
  echo "[FAIL] Dependency installation failed"
  exit 1
fi

# --- Run build if script exists ---

has_script() {
  node -e "
    const pkg = JSON.parse(require('fs').readFileSync('package.json','utf8'));
    process.exit(pkg.scripts && pkg.scripts['$1'] ? 0 : 1);
  " 2>/dev/null
}

if has_script "build"; then
  echo "[INFO] Running build..."
  if $PM run build; then
    echo "[PASS] Build succeeded"
  else
    echo "[FAIL] Build failed"
    exit 1
  fi
else
  echo "[SKIP] No build script found in package.json"
fi

# --- Summary ---

ELAPSED=$(( SECONDS - START_TIME ))
echo "--- SUMMARY ---"
echo "Package manager: $PM | Elapsed: ${ELAPSED}s"
