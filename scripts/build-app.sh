#!/usr/bin/env bash
# Builds Pyno and assembles dist/Pyno.app (plus dist/Pyno.zip for distribution).
#
#   ./scripts/build-app.sh
#   DEVELOPER_ID="Developer ID Application: Name (TEAMID)" ./scripts/build-app.sh
#
# Without DEVELOPER_ID the app is ad-hoc signed: it runs on this machine, but anyone
# else has to clear the Gatekeeper quarantine by hand (see README).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="dist/Pyno.app"
CONTENTS="$APP/Contents"

echo "==> Building (release, arm64)"
swift build -c release --arch arm64

if [ ! -f Resources/AppIcon.icns ]; then
  echo "==> Generating the icon"
  swift scripts/make-icon.swift Resources/AppIcon.icns
fi

echo "==> Assembling the bundle"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

BUILD_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

cp "$BUILD_DIR/Pyno" "$CONTENTS/MacOS/Pyno"
cp Resources/Info.plist "$CONTENTS/Info.plist"
cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
for lproj in Resources/*.lproj; do
  cp -R "$lproj" "$CONTENTS/Resources/"
done
printf 'APPL????' > "$CONTENTS/PkgInfo"

# Resource bundles produced by SwiftPM (Bundle.module looks for them in Contents/Resources).
shopt -s nullglob
for bundle in "$BUILD_DIR"/*.bundle; do
  cp -R "$bundle" "$CONTENTS/Resources/"
  chmod -R u+w "$CONTENTS/Resources/$(basename "$bundle")"
done
shopt -u nullglob

echo "==> Signing"
# Any nested bundle that carries its own Info.plist has to be signed before the app
# around it. SwiftPM resource bundles usually carry none — they are plain folders of
# data files, which codesign refuses to treat as bundles and the app seals as
# ordinary resources instead.
sign_nested() {
  shopt -s nullglob
  for nested in "$CONTENTS/Resources"/*.bundle; do
    [ -f "$nested/Info.plist" ] || [ -f "$nested/Contents/Info.plist" ] || continue
    codesign "$@" "$nested"
  done
  shopt -u nullglob
}

if [ -n "${DEVELOPER_ID:-}" ]; then
  sign_nested --force --timestamp --options runtime --sign "$DEVELOPER_ID"
  codesign --force --timestamp --options runtime \
    --entitlements Resources/Pyno.entitlements \
    --sign "$DEVELOPER_ID" "$APP"
  echo "    signed with $DEVELOPER_ID (hardened runtime)"
else
  sign_nested --force --sign -
  codesign --force --sign - "$APP"
  echo "    ad-hoc signature (no Developer ID) — other Macs will refuse to open this"
fi
codesign --verify --strict --verbose=2 "$APP"

echo "==> Archiving"
rm -f dist/Pyno.zip
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/Pyno.zip

echo
echo "Done:"
echo "  $APP"
echo "  dist/Pyno.zip   ($(du -h dist/Pyno.zip | cut -f1))"
