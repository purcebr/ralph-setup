#!/usr/bin/env bash
set -euo pipefail

# scan-secrets.sh — Scan staged files for secrets and credentials.
# Prevents accidental commits of API keys, tokens, and private keys.
# Usage: scan-secrets.sh [--hook-mode]
#   --hook-mode: exit 2 (blocked) instead of 1 for Kiro preToolUse hooks

HOOK_MODE=false
if [ "${1:-}" = "--hook-mode" ]; then
  HOOK_MODE=true
fi

FOUND=0

# --- Get staged files ---

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  echo "[PASS] No staged files to scan"
  exit 0
fi

echo "[INFO] Scanning $(echo "$STAGED_FILES" | wc -l | tr -d ' ') staged file(s) for secrets..."

# --- Check for dangerous file types ---

while IFS= read -r file; do
  [ -z "$file" ] && continue

  basename=$(basename "$file")
  case "$basename" in
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|credentials.*|*secret*)
      echo "[FAIL] Sensitive file staged: $file"
      FOUND=$((FOUND + 1))
      continue
      ;;
  esac

  # Skip binary files
  if file "$file" 2>/dev/null | grep -q "binary"; then
    continue
  fi

  # --- Pattern scan file contents ---

  # AWS Access Keys
  if grep -nE 'AKIA[0-9A-Z]{16}' "$file" 2>/dev/null; then
    echo "[FAIL] AWS access key pattern found in $file"
    FOUND=$((FOUND + 1))
  fi

  # Private keys
  if grep -nE '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----' "$file" 2>/dev/null; then
    echo "[FAIL] Private key found in $file"
    FOUND=$((FOUND + 1))
  fi

  # Generic API key/token/secret assignments
  if grep -nEi '(api_key|api_secret|apikey|secret_key|access_token|auth_token|private_key)\s*[:=]\s*["\x27][A-Za-z0-9+/=_-]{20,}' "$file" 2>/dev/null; then
    echo "[FAIL] Possible API key/token assignment in $file"
    FOUND=$((FOUND + 1))
  fi

  # Password assignments
  if grep -nEi '(password|passwd|pwd)\s*[:=]\s*["\x27][^\s"'\'']{8,}' "$file" 2>/dev/null; then
    echo "[FAIL] Possible hardcoded password in $file"
    FOUND=$((FOUND + 1))
  fi

  # Connection strings with passwords
  if grep -nEi '(mongodb|postgres|mysql|redis)://[^:]+:[^@]+@' "$file" 2>/dev/null; then
    echo "[FAIL] Connection string with credentials in $file"
    FOUND=$((FOUND + 1))
  fi

done <<< "$STAGED_FILES"

# --- Result ---

echo ""
if [ "$FOUND" -gt 0 ]; then
  echo "[FAIL] Found $FOUND potential secret(s) in staged files"
  echo "--- SUMMARY ---"
  echo "Total scanned: $(echo "$STAGED_FILES" | wc -l | tr -d ' ') | Findings: $FOUND"
  if [ "$HOOK_MODE" = true ]; then
    exit 2
  fi
  exit 1
else
  echo "[PASS] No secrets detected in staged files"
  echo "--- SUMMARY ---"
  echo "Total scanned: $(echo "$STAGED_FILES" | wc -l | tr -d ' ') | Findings: 0"
  exit 0
fi
