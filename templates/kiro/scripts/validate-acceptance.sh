#!/usr/bin/env bash
set -euo pipefail

# validate-acceptance.sh — Validate acceptance criteria for a user story from prd.json.
# Usage: validate-acceptance.sh <story-id> [--prd <path>]
# Example: validate-acceptance.sh US-001

if [ $# -eq 0 ]; then
  echo "Usage: validate-acceptance.sh <story-id> [--prd <path>]"
  echo "Example: validate-acceptance.sh US-001"
  exit 1
fi

STORY_ID="$1"
shift

PRD_PATH="./prd.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --prd) PRD_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ ! -f "$PRD_PATH" ]; then
  echo "[FAIL] prd.json not found at $PRD_PATH"
  exit 1
fi

# --- Extract acceptance criteria to temp file ---

CRITERIA_FILE=$(mktemp)
trap 'rm -f "$CRITERIA_FILE"' EXIT

node -e "
  const prd = JSON.parse(require('fs').readFileSync('$PRD_PATH', 'utf8'));
  const story = prd.userStories.find(s => s.id === '$STORY_ID');
  if (!story) { console.error('Story $STORY_ID not found'); process.exit(1); }
  story.acceptanceCriteria.forEach(c => console.log(c));
" > "$CRITERIA_FILE" 2>&1 || {
  echo "[FAIL] Could not find story $STORY_ID in $PRD_PATH"
  exit 1
}

TOTAL=$(wc -l < "$CRITERIA_FILE" | tr -d ' ')
PASSED=0
FAILED=0
SKIPPED=0

echo "[INFO] Validating $TOTAL acceptance criteria for $STORY_ID"
echo ""

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

# --- Check each criterion ---

check_criterion() {
  local criterion="$1"
  local lower
  lower=$(echo "$criterion" | tr '[:upper:]' '[:lower:]')

  # Pattern: "npm install completes" / "npm install succeeds"
  if echo "$lower" | grep -qE 'npm install.*(completes|succeeds|without error)'; then
    if $PM install --ignore-scripts >/dev/null 2>&1; then
      echo "[PASS] $criterion"
      return 0
    else
      echo "[FAIL] $criterion"
      return 1
    fi
  fi

  # Pattern: "npm run <script> succeeds/passes"
  local script
  script=$(echo "$lower" | grep -oE 'npm run [a-z:_-]+' | head -1 | sed 's/npm run //' || true)
  if [ -n "$script" ] && echo "$lower" | grep -qE '(succeeds|passes|no (errors|failures))'; then
    if $PM run "$script" >/dev/null 2>&1; then
      echo "[PASS] $criterion"
      return 0
    else
      echo "[FAIL] $criterion"
      return 1
    fi
  fi

  # Pattern: "npm test passes"
  if echo "$lower" | grep -qE 'npm test.*(passes|succeeds)'; then
    if $PM test >/dev/null 2>&1; then
      echo "[PASS] $criterion"
      return 0
    else
      echo "[FAIL] $criterion"
      return 1
    fi
  fi

  # Pattern: file existence — "<path> exists" or "contains a <path>"
  local filepath
  filepath=$(echo "$criterion" | grep -oE '[a-zA-Z0-9_./-]+\.(js|ts|jsx|tsx|json|html|css|md|toml|yaml|yml|sh)' | head -1 || true)
  if [ -n "$filepath" ]; then
    # Check if the criterion is about file existence or exports
    if echo "$lower" | grep -qE '(exports?|contains).*function|exports? a'; then
      # Pattern: "<file> exports a <name>() function"
      local func_name
      func_name=$(echo "$criterion" | grep -oE 'exports? (a )?([a-zA-Z_][a-zA-Z0-9_]*)' | awk '{print $NF}' || true)
      if [ -n "$func_name" ] && [ -f "$filepath" ]; then
        if grep -qE "(export|module\.exports).*(function\s+$func_name|$func_name\s*[:=])" "$filepath" 2>/dev/null; then
          echo "[PASS] $criterion"
          return 0
        else
          echo "[FAIL] $criterion"
          return 1
        fi
      fi
    fi

    # File existence check
    if [ -f "$filepath" ]; then
      echo "[PASS] $criterion (file exists: $filepath)"
      return 0
    else
      echo "[FAIL] $criterion (file not found: $filepath)"
      return 1
    fi
  fi

  # Pattern: HTTP endpoint — "GET/POST/PATCH/DELETE /path returns <status>"
  if echo "$lower" | grep -qE '(get|post|put|patch|delete) /[a-z]'; then
    echo "[SKIP] $criterion (HTTP endpoint check requires running server)"
    return 2
  fi

  # Unrecognized criterion
  echo "[SKIP] $criterion (cannot verify automatically)"
  return 2
}

# --- Iterate criteria ---

while IFS= read -r criterion; do
  [ -z "$criterion" ] && continue
  RESULT=0
  check_criterion "$criterion" || RESULT=$?
  case "$RESULT" in
    0) PASSED=$((PASSED + 1)) ;;
    1) FAILED=$((FAILED + 1)) ;;
    2) SKIPPED=$((SKIPPED + 1)) ;;
  esac
done < "$CRITERIA_FILE"

# --- Summary ---

echo ""
echo "--- SUMMARY ---"
echo "Story: $STORY_ID | Total: $TOTAL | Passed: $PASSED | Failed: $FAILED | Skipped: $SKIPPED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
else
  exit 0
fi
