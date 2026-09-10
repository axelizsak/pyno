#!/usr/bin/env bash
# Build, sign, notarize and package Pyno so that anyone can download it and open it
# with no warning at all — no Gatekeeper prompt, no right-click trick, no terminal.
#
#   ./scripts/release.sh              build and notarize into dist/
#   ./scripts/release.sh --publish    also cut the GitHub release and upload the .dmg
#
# First time through, run ./scripts/setup-signing.sh — it walks the certificate and
# the notarization password. DEVELOPER_ID is picked up from the keychain on its own.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NOTARY_PROFILE="${NOTARY_PROFILE:-pyno-notary}"
PUBLISH=0
if [ "${1:-}" = "--publish" ]; then PUBLISH=1; fi

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

if [ -z "${DEVELOPER_ID:-}" ]; then
  DEVELOPER_ID="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/' || true)"
fi
if [ -z "$DEVELOPER_ID" ]; then
  echo "error: no Developer ID Application certificate found." >&2
  echo "       Run ./scripts/setup-signing.sh csr to get one." >&2
  exit 1
fi
export DEVELOPER_ID

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "error: no notarization credentials stored as '$NOTARY_PROFILE'." >&2
  echo "       Run ./scripts/setup-signing.sh notary." >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
bold "Releasing Pyno $VERSION as $DEVELOPER_ID"
echo

notarize() {
  local what="$1"
  echo "==> Notarizing $what (usually 1-5 minutes)"
  xcrun notarytool submit "$what" --keychain-profile "$NOTARY_PROFILE" --wait
}

./scripts/build-app.sh

# The app is notarized first and stapled, so the ticket travels inside the bundle.
# A copy pulled out of the disk image then opens even on a Mac that is offline.
notarize dist/Pyno.zip
echo "==> Stapling the app"
xcrun stapler staple dist/Pyno.app

echo "==> Re-archiving the stapled app"
rm -f dist/Pyno.zip
ditto -c -k --sequesterRsrc --keepParent dist/Pyno.app dist/Pyno.zip

./scripts/make-dmg.sh

notarize dist/Pyno.dmg
echo "==> Stapling the disk image"
xcrun stapler staple dist/Pyno.dmg

echo
bold "Verifying the way Gatekeeper will"
xcrun stapler validate dist/Pyno.app
xcrun stapler validate dist/Pyno.dmg
spctl --assess --type execute --verbose=4 dist/Pyno.app
spctl --assess --type open --context context:primary-signature --verbose=4 dist/Pyno.dmg

SHA="$(shasum -a 256 dist/Pyno.dmg | cut -d' ' -f1)"
echo
bold "dist/Pyno.dmg — $(du -h dist/Pyno.dmg | cut -f1)"
echo "sha256  $SHA"

if [ "$PUBLISH" -eq 1 ]; then
  TAG="v$VERSION"
  echo
  bold "Publishing $TAG on GitHub"
  command -v gh >/dev/null || { echo "error: the gh CLI is not installed" >&2; exit 1; }

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: commit or stash your changes before publishing." >&2
    exit 1
  fi
  git rev-parse "$TAG" >/dev/null 2>&1 || git tag -a "$TAG" -m "Pyno $VERSION"
  git push origin "$TAG"

  gh release create "$TAG" dist/Pyno.dmg \
    --title "Pyno $VERSION" \
    --notes "$(cat <<NOTES
Live, fully local speech-to-text for Apple Silicon Macs.

**Download \`Pyno.dmg\`, open it, drag Pyno to Applications.** Signed and notarized
by Apple, so it opens on the first double-click with no security warning.

Requires an Apple Silicon Mac (M1 or newer) on macOS 14 or later. On first launch
Pyno downloads its speech model once, about 470 MB. Everything after that is offline.

\`\`\`
sha256  $SHA
\`\`\`
NOTES
)"
  echo
  bold "Live: $(gh release view "$TAG" --json url --jq .url)"
else
  echo
  echo "Upload dist/Pyno.dmg anywhere that serves a plain download link, or rerun with"
  echo "--publish to cut the GitHub release automatically."
fi
