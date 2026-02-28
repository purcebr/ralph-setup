#!/usr/bin/env bash
set -euo pipefail

# safe-git.sh — Git wrapper with security guardrails.
# Allows: branch, add, commit, status, diff, log
# Blocks: push, remote, reset --hard, clean -f, rebase

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -eq 0 ]; then
  echo "Usage: safe-git.sh <command> [args...]"
  echo "Allowed: branch, add, commit, status, diff, log"
  echo "Blocked: push, remote, reset, clean, rebase"
  exit 1
fi

CMD="$1"
shift

# --- Block dangerous commands ---

case "$CMD" in
  push|remote|rebase)
    echo "[FAIL] BLOCKED: 'git $CMD' is not allowed for security reasons"
    exit 1
    ;;
  reset)
    if echo "$*" | grep -q -- "--hard"; then
      echo "[FAIL] BLOCKED: 'git reset --hard' is not allowed"
      exit 1
    fi
    ;;
  clean)
    if echo "$*" | grep -q -- "-f"; then
      echo "[FAIL] BLOCKED: 'git clean -f' is not allowed"
      exit 1
    fi
    ;;
esac

# --- Handle allowed commands ---

case "$CMD" in
  status)
    git status "$@"
    ;;

  diff)
    git diff "$@"
    ;;

  log)
    git log "$@"
    ;;

  branch)
    # Allow create/switch but block deletion of main/master
    for arg in "$@"; do
      if [ "$arg" = "-D" ] || [ "$arg" = "-d" ]; then
        # Check if trying to delete main or master
        if echo "$*" | grep -qE '(main|master)'; then
          echo "[FAIL] BLOCKED: Cannot delete main/master branch"
          exit 1
        fi
      fi
    done
    git branch "$@"
    ;;

  add)
    # Filter out sensitive files
    FILTERED_ARGS=()
    SKIPPED=()
    for arg in "$@"; do
      basename=$(basename "$arg" 2>/dev/null || echo "$arg")
      case "$basename" in
        .env|.env.*|*.pem|*.key|*.p12|*.pfx|credentials.*)
          SKIPPED+=("$arg")
          ;;
        *)
          FILTERED_ARGS+=("$arg")
          ;;
      esac
    done

    if [ ${#SKIPPED[@]} -gt 0 ]; then
      for s in "${SKIPPED[@]}"; do
        echo "[SKIP] Refusing to stage sensitive file: $s"
      done
    fi

    if [ ${#FILTERED_ARGS[@]} -gt 0 ]; then
      git add "${FILTERED_ARGS[@]}"
      echo "[PASS] Staged ${#FILTERED_ARGS[@]} file(s)"
    else
      echo "[INFO] No files to stage after filtering"
    fi
    ;;

  commit)
    # Block --no-verify
    for arg in "$@"; do
      if [ "$arg" = "--no-verify" ] || [ "$arg" = "-n" ]; then
        echo "[FAIL] BLOCKED: --no-verify is not allowed"
        exit 1
      fi
    done

    # Run secret scan before commit
    echo "[INFO] Running secret scan before commit..."
    if ! "$SCRIPT_DIR/scan-secrets.sh"; then
      echo "[FAIL] Commit blocked: secrets detected in staged files"
      exit 1
    fi

    git commit "$@"
    echo "[PASS] Commit created"
    ;;

  *)
    echo "[FAIL] Unknown command: git $CMD"
    echo "Allowed: branch, add, commit, status, diff, log"
    exit 1
    ;;
esac
