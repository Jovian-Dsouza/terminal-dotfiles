#!/usr/bin/env bash
# Scan tracked + staged content for common secret patterns.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "validate-no-secrets: not a git repository" >&2
  exit 1
fi

TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_LIST" /tmp/validate-no-secrets-hits 2>/dev/null' EXIT

{
  git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true
  git ls-files
} | sort -u >"$TMP_LIST"

FILE_COUNT=0
PATTERNS=(
  'gh[pousr]_[A-Za-z0-9_]{20,}'
  'github_pat_[A-Za-z0-9_]{20,}'
  'AKIA[0-9A-Z]{16}'
  '-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----'
  'sk-[A-Za-z0-9]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'
)

FAIL=0
while IFS= read -r file || [[ -n "$file" ]]; do
  [[ -n "$file" ]] || continue
  [[ -f "$file" ]] || continue
  case "$file" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.woff|*.woff2|*.ttf|*.otf) continue ;;
  esac
  FILE_COUNT=$((FILE_COUNT + 1))
  for pat in "${PATTERNS[@]}"; do
    if grep -nE -- "$pat" "$file" >/tmp/validate-no-secrets-hits 2>/dev/null; then
      echo "SECRET PATTERN MATCH in $file (pattern: $pat):" >&2
      sed 's/^/  /' /tmp/validate-no-secrets-hits >&2
      FAIL=1
    fi
  done
done <"$TMP_LIST"

while IFS= read -r tracked; do
  base="$(basename "$tracked")"
  case "$base" in
    .env|.env.*|credentials.json|secrets.json|*.pem|id_rsa|id_ed25519)
      echo "Blocked tracked secret-like path: $tracked" >&2
      FAIL=1
      ;;
  esac
done < <(git ls-files)

while IFS= read -r tracked; do
  case "$tracked" in
    *.log|.config/herdr/.plugins.lock|.config/herdr/release-notes.json)
      echo "Blocked herdr runtime file: $tracked" >&2
      FAIL=1
      ;;
  esac
done < <(git ls-files)

if ((FAIL)); then
  echo "validate-no-secrets: FAILED — remove secrets before push." >&2
  exit 1
fi

echo "validate-no-secrets: OK ($FILE_COUNT files scanned)"
