#!/usr/bin/env bash
set -euo pipefail

# run-tests.sh — Run the project test suite and output structured results.
# Batches test execution + result parsing into one shell call.

START_TIME=$SECONDS

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

# --- Detect test script ---

has_script() {
  node -e "
    const pkg = JSON.parse(require('fs').readFileSync('package.json','utf8'));
    process.exit(pkg.scripts && pkg.scripts['$1'] ? 0 : 1);
  " 2>/dev/null
}

TEST_SCRIPT=""
for candidate in "test" "test:unit" "test:all"; do
  if has_script "$candidate"; then
    TEST_SCRIPT="$candidate"
    break
  fi
done

if [ -z "$TEST_SCRIPT" ]; then
  echo "[SKIP] No test script found in package.json"
  echo "--- SUMMARY ---"
  echo "Total: 0 | Passed: 0 | Failed: 0 | Skipped: 1"
  exit 0
fi

# --- Run tests ---

echo "[INFO] Running: $PM run $TEST_SCRIPT"

TEST_OUTPUT=""
EXIT_CODE=0
TEST_OUTPUT=$($PM run "$TEST_SCRIPT" 2>&1) || EXIT_CODE=$?

echo "$TEST_OUTPUT"

# --- Parse results ---

ELAPSED=$(( SECONDS - START_TIME ))

if [ "$EXIT_CODE" -eq 0 ]; then
  echo ""
  echo "[PASS] All tests passed"
  echo "--- SUMMARY ---"
  echo "Test script: $TEST_SCRIPT | Result: PASS | Elapsed: ${ELAPSED}s"
  exit 0
else
  echo ""
  echo "[FAIL] Tests failed (exit code: $EXIT_CODE)"
  echo "--- SUMMARY ---"
  echo "Test script: $TEST_SCRIPT | Result: FAIL | Elapsed: ${ELAPSED}s"
  exit 1
fi
