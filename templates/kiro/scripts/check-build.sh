#!/usr/bin/env bash
set -euo pipefail

# check-build.sh — Full build verification pipeline in one call.
# Runs lint, typecheck, build, and tests. Reports aggregate results.
# Usage: check-build.sh [--quiet]

QUIET=false
if [ "${1:-}" = "--quiet" ]; then
  QUIET=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Detect package manager ---

detect_pm() {
  if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
    echo "bun"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "yarn.lock" ]; then
    echo "yarn"
  else
    echo "npm"
  fi
}

PM=$(detect_pm)

has_script() {
  node -e "
    const pkg = JSON.parse(require('fs').readFileSync('package.json','utf8'));
    process.exit(pkg.scripts && pkg.scripts['$1'] ? 0 : 1);
  " 2>/dev/null
}

LINT_STATUS="SKIP"
TYPES_STATUS="SKIP"
BUILD_STATUS="SKIP"
TESTS_STATUS="SKIP"
FAILURES=0

# --- Lint ---

if has_script "lint"; then
  if [ "$QUIET" = false ]; then echo "[INFO] Running lint..."; fi
  if $PM run lint >/dev/null 2>&1; then
    LINT_STATUS="PASS"
    if [ "$QUIET" = false ]; then echo "[PASS] Lint"; fi
  else
    LINT_STATUS="FAIL"
    FAILURES=$((FAILURES + 1))
    if [ "$QUIET" = false ]; then echo "[FAIL] Lint"; fi
  fi
else
  if [ "$QUIET" = false ]; then echo "[SKIP] No lint script"; fi
fi

# --- Typecheck ---

if has_script "typecheck"; then
  if [ "$QUIET" = false ]; then echo "[INFO] Running typecheck..."; fi
  if $PM run typecheck >/dev/null 2>&1; then
    TYPES_STATUS="PASS"
    if [ "$QUIET" = false ]; then echo "[PASS] Typecheck"; fi
  else
    TYPES_STATUS="FAIL"
    FAILURES=$((FAILURES + 1))
    if [ "$QUIET" = false ]; then echo "[FAIL] Typecheck"; fi
  fi
else
  if [ "$QUIET" = false ]; then echo "[SKIP] No typecheck script"; fi
fi

# --- Build ---

if has_script "build"; then
  if [ "$QUIET" = false ]; then echo "[INFO] Running build..."; fi
  if $PM run build >/dev/null 2>&1; then
    BUILD_STATUS="PASS"
    if [ "$QUIET" = false ]; then echo "[PASS] Build"; fi
  else
    BUILD_STATUS="FAIL"
    FAILURES=$((FAILURES + 1))
    if [ "$QUIET" = false ]; then echo "[FAIL] Build"; fi
  fi
else
  if [ "$QUIET" = false ]; then echo "[SKIP] No build script"; fi
fi

# --- Tests ---

if has_script "test"; then
  if [ "$QUIET" = false ]; then echo "[INFO] Running tests..."; fi
  if "$SCRIPT_DIR/run-tests.sh" >/dev/null 2>&1; then
    TESTS_STATUS="PASS"
    if [ "$QUIET" = false ]; then echo "[PASS] Tests"; fi
  else
    TESTS_STATUS="FAIL"
    FAILURES=$((FAILURES + 1))
    if [ "$QUIET" = false ]; then echo "[FAIL] Tests"; fi
  fi
else
  if [ "$QUIET" = false ]; then echo "[SKIP] No test script"; fi
fi

# --- Summary ---

echo "--- SUMMARY ---"
echo "Lint: $LINT_STATUS | Types: $TYPES_STATUS | Build: $BUILD_STATUS | Tests: $TESTS_STATUS"

if [ "$FAILURES" -gt 0 ]; then
  echo "Result: FAIL ($FAILURES check(s) failed)"
  exit 1
else
  echo "Result: PASS"
  exit 0
fi
