#!/usr/bin/env bash
# Full release: build, sign with a Developer ID, package as a .dmg, notarize, staple.
# The result is a disk image anyone can download and open with no warnings.
#
# One-time setup (stores an app-specific password in the keychain):
#
#   xcrun notarytool store-credentials pyno-notary \
#     --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
#
# App-specific passwords come from https://account.apple.com → Sign-In and Security.
#
# Then:
#
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="${NOTARY_PROFILE:-pyno-notary}"

if [ -z "${DEVELOPER_ID:-}" ]; then
  echo "error: set DEVELOPER_ID first. Available identities:" >&2
  security find-identity -v -p codesigning >&2
  exit 1
fi

./scripts/build-app.sh
./scripts/make-dmg.sh

echo "==> Notarizing (this usually takes 1-5 minutes)"
xcrun notarytool submit dist/Pyno.dmg --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple dist/Pyno.dmg
xcrun stapler validate dist/Pyno.dmg

echo
echo "dist/Pyno.dmg is signed, notarized and stapled."
echo "Upload it anywhere and share the link — it opens with no Gatekeeper warning."
