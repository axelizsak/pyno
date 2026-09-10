#!/usr/bin/env bash
# Point the GitHub Pages site at a domain you own.
#
#   ./scripts/set-custom-domain.sh pyno.dev
#
# Do this only once the DNS records below already resolve. Writing the CNAME file
# first would take the github.io address down until they do.
#
#   A     @     185.199.108.153
#   A     @     185.199.109.153
#   A     @     185.199.110.153
#   A     @     185.199.111.153
#   CNAME www   axelizsak.github.io
#
# On Cloudflare, leave those records DNS-only (grey cloud, not orange). GitHub has
# to reach the domain itself to get a certificate issued, and the proxy blocks that.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DOMAIN="${1:-}"
REPO="${REPO:-axelizsak/pyno}"
[ -n "$DOMAIN" ] || { echo "usage: set-custom-domain.sh <domain>" >&2; exit 1; }

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

echo "==> Checking that $DOMAIN points at GitHub Pages"
GH_IPS="185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153"
# The local resolver may still be caching the pre-purchase answer, so fall back to
# a public one before concluding the records are missing.
RESOLVED="$(dig +short "$DOMAIN" A | sort | tr '\n' ' ')"
if [ -z "${RESOLVED// /}" ]; then
  RESOLVED="$(dig +short "$DOMAIN" A @1.1.1.1 | sort | tr '\n' ' ')"
fi
if [ -z "${RESOLVED// /}" ]; then
  echo "error: $DOMAIN does not resolve yet. Add the A records and wait." >&2
  exit 1
fi
MATCHED=0
for ip in $RESOLVED; do
  case " $GH_IPS " in *" $ip "*) MATCHED=1 ;; esac
done
if [ "$MATCHED" -eq 0 ]; then
  echo "error: $DOMAIN resolves to $RESOLVED, none of which is GitHub Pages." >&2
  echo "       If this is Cloudflare, switch the records to DNS-only." >&2
  exit 1
fi
echo "    $DOMAIN -> $RESOLVED"

echo "==> Writing docs/CNAME"
printf '%s\n' "$DOMAIN" > docs/CNAME

echo "==> Updating the links in the page and the README"
OLD_URL="https://axelizsak.github.io/pyno/"
NEW_URL="https://$DOMAIN/"
for f in docs/index.html README.md; do
  perl -pi -e "s{\Qhttps://axelizsak.github.io/pyno/\E}{$NEW_URL}g" "$f"
done

git add -A
git commit -q -m "Serve the site from $DOMAIN"
git push -q origin main

echo "==> Telling GitHub Pages about it"
gh api -X PUT "repos/$REPO/pages" -f "cname=$DOMAIN" >/dev/null
gh api -X PATCH "repos/$REPO" -f "homepage=$NEW_URL" >/dev/null

echo "==> Waiting for the certificate (this can take up to an hour)"
for i in $(seq 1 40); do
  state="$(gh api "repos/$REPO/pages" --jq '.https_certificate.state // "pending"' 2>/dev/null || echo pending)"
  code="$(curl -s -o /dev/null -w '%{http_code}' "$NEW_URL" || echo 000)"
  echo "    attempt $i: certificate=$state http=$code"
  if [ "$code" = "200" ]; then
    gh api -X PUT "repos/$REPO/pages" -F "https_enforced=true" >/dev/null 2>&1 || true
    echo
    bold "Live at $NEW_URL with HTTPS enforced."
    exit 0
  fi
  sleep 45
done

echo
echo "Still waiting on the certificate. It usually lands within the hour."
echo "Check with: gh api repos/$REPO/pages --jq '.https_certificate.state'"
