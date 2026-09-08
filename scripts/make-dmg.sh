#!/usr/bin/env bash
# Packages dist/Pyno.app into dist/Pyno.dmg — a disk image with an Applications
# shortcut, so installing is "open, drag, done" for someone non-technical.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="dist/Pyno.app"
DMG="dist/Pyno.dmg"
STAGING="dist/dmg-staging"

[ -d "$APP" ] || { echo "error: $APP not found — run scripts/build-app.sh first" >&2; exit 1; }

echo "==> Staging"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating disk image"
hdiutil create \
  -volname "Pyno" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGING"
echo "Done: $DMG ($(du -h "$DMG" | cut -f1))"
