#!/usr/bin/env bash
# verify-pages.sh — Validate K2 Insurance email logo CDN endpoints.
#
# Run AFTER GitHub Pages is enabled (Settings → Pages → Source: master / root).
# Pages typically takes 1–2 minutes to build on first activation.
#
# Usage:
#   ./scripts/verify-pages.sh
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
#
# What is checked, per URL:
#   1. HTTP 200 OK
#   2. Content-Type is image/png
#   3. HTTPS redirect/enforcement (request must succeed over https://)

set -u

PRIMARY="https://archliam.github.io/K2Insurance/email/logo.png"
BACKUP="https://cdn.jsdelivr.net/gh/ArchLiam/K2Insurance@master/email/logo.png"

FAIL=0

check_url() {
  local label="$1"
  local url="$2"
  echo
  echo "── [$label] $url"

  # Reject non-https inputs defensively.
  if [[ "$url" != https://* ]]; then
    echo "  ✗ URL is not HTTPS"
    FAIL=1
    return
  fi

  # -s silent, -S show error, -L follow redirects, -I head request, -o stderr to /dev/null
  local headers
  headers="$(curl -sSIL --max-time 15 "$url" 2>/dev/null)" || {
    echo "  ✗ curl failed (network / DNS / TLS)"
    FAIL=1
    return
  }

  # Last status line (after redirects).
  local status
  status="$(printf '%s\n' "$headers" | awk 'toupper($1) ~ /^HTTP\// {s=$2} END{print s}')"
  if [[ "$status" == "200" ]]; then
    echo "  ✓ HTTP 200"
  else
    echo "  ✗ HTTP status: ${status:-<none>}"
    FAIL=1
  fi

  local ctype
  ctype="$(printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^content-type:/ {sub(/\r$/,""); print tolower($2); exit}')"
  if [[ "$ctype" == image/png* ]]; then
    echo "  ✓ Content-Type: $ctype"
  else
    echo "  ✗ Content-Type: ${ctype:-<missing>} (expected image/png)"
    FAIL=1
  fi
}

echo "K2 Insurance — Email Logo CDN verification"
echo "==========================================="

check_url "Primary (GitHub Pages)" "$PRIMARY"
check_url "Backup  (jsDelivr CDN)" "$BACKUP"

echo
echo "==========================================="
if [[ $FAIL -eq 0 ]]; then
  echo "✓ All checks passed. Letterhead can safely reference the Primary URL."
  exit 0
else
  echo "✗ One or more checks failed. Investigate before updating Salesforce Letterhead."
  echo
  echo "Common causes:"
  echo "  • Pages not yet enabled, or first build still in progress (wait 2 min, retry)"
  echo "  • Repo private or default branch differs from 'master'"
  echo "  • logo.png not committed to email/ on the default branch"
  exit 1
fi
