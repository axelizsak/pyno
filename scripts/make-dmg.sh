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

# An unsigned build is blocked on first launch. Ship the way around it in the image.
if ! codesign -dv "$APP" 2>&1 | grep -q "Authority=Developer ID Application"; then
  cat > "$STAGING/OPEN ME FIRST.txt" <<'NOTICE'
Pyno — first launch
===================

Pyno is not yet signed with an Apple Developer ID, so macOS blocks it the first
time. This only has to be done once.

1. Drag Pyno onto the Applications folder in this window.
2. Open Applications and double-click Pyno. macOS will refuse.
3. Open System Settings > Privacy & Security, scroll to the bottom, and click
   "Open Anyway" next to the message about Pyno. Confirm with your password.
4. Pyno opens. Allow microphone access when asked.

On first launch Pyno downloads its speech model (about 470 MB). After that it
works entirely offline — audio never leaves your Mac.

Requires an Apple Silicon Mac (M1 or newer) on macOS 14 or later.


Pyno — premier lancement
========================

Pyno n'est pas encore signé avec un identifiant Apple Developer, donc macOS le
bloque au premier lancement. C'est à faire une seule fois.

1. Glisse Pyno sur le dossier Applications dans cette fenêtre.
2. Ouvre Applications et double-clique sur Pyno. macOS va refuser.
3. Ouvre Réglages Système > Confidentialité et sécurité, descends tout en bas et
   clique sur « Ouvrir quand même » à côté du message concernant Pyno. Confirme
   avec ton mot de passe.
4. Pyno s'ouvre. Autorise l'accès au micro quand il le demande.

Au premier lancement, Pyno télécharge son modèle de reconnaissance vocale
(environ 470 Mo). Ensuite tout fonctionne hors-ligne — l'audio ne quitte
jamais ton Mac.

Nécessite un Mac Apple Silicon (M1 ou plus récent) sous macOS 14 ou plus.
NOTICE
fi

echo "==> Creating disk image"
hdiutil create \
  -volname "Pyno" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGING"
echo "Done: $DMG ($(du -h "$DMG" | cut -f1))"
