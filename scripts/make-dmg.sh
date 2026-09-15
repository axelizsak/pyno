#!/usr/bin/env bash
# Packages dist.noindex/Pyno.app into dist.noindex/Pyno.dmg — a disk image that
# opens on a styled window: Pyno on the left, Applications on the right, an arrow
# between them. So installing is "open, drag, done" for someone non-technical.
#
# The window layout is written by dmgbuild (Python, installed once into .build/),
# which sets Finder's view options directly instead of scripting Finder — so it
# needs no Automation permission and gives the same result on every run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="dist.noindex/Pyno.app"
DMG="dist.noindex/Pyno.dmg"
WORK="dist.noindex/dmg-work"
VENV=".build/dmgbuild"
# 1.6.7 stores the background as a bookmark. Earlier versions write a legacy alias
# that Finder on macOS 15 and 26 no longer resolves, and the window comes up blank.
DMGBUILD_VERSION="1.6.7"

[ -d "$APP" ] || { echo "error: $APP not found — run scripts/build-app.sh first" >&2; exit 1; }

if [ "$("$VENV/bin/pip" show dmgbuild 2>/dev/null | sed -n 's/^Version: //p')" != "$DMGBUILD_VERSION" ]; then
  echo "==> Installing dmgbuild $DMGBUILD_VERSION into $VENV"
  rm -rf "$VENV"
  /usr/bin/python3 -m venv "$VENV"
  # It declares Python 3.10, but runs on the 3.9 macOS ships, and nothing newer is
  # guaranteed to be installed.
  "$VENV/bin/pip" install --quiet --disable-pip-version-check --ignore-requires-python \
    "dmgbuild==$DMGBUILD_VERSION"
fi

rm -rf "$WORK" "$DMG"
mkdir -p "$WORK"

echo "==> Drawing the window background"
swift scripts/make-dmg-background.swift "$WORK/background.png" "$WORK/background@2x.png"
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" \
  -out "$WORK/background.tiff" 2>/dev/null

# An unsigned build is blocked on first launch. Ship the way around it in the image.
# A Developer ID build never gets this file: it opens on the first double-click.
# (`-dv` alone does not print the Authority lines; it takes `-dvv`.)
NOTICE=""
if ! codesign -dvv "$APP" 2>&1 | grep "Authority=Developer ID Application" >/dev/null; then
  NOTICE="$WORK/OPEN ME FIRST.txt"
  cat > "$NOTICE" <<'NOTICE'
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
  echo "    unsigned app — adding OPEN ME FIRST.txt"
fi

# Icon centers match appCenter / applicationsCenter in make-dmg-background.swift.
cat > "$WORK/settings.py" <<'SETTINGS'
app = defines["app"]
notice = defines.get("notice") or None

format = "UDZO"
filesystem = "HFS+"
files = [app] + ([notice] if notice else [])
symlinks = {"Applications": "/Applications"}
icon = defines["volume_icon"]

background = defines["background"]
window_rect = ((200, 140), (660, 448))  # 420 of background plus the title bar
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True

arrange_by = None
icon_size = 128
text_size = 13
icon_locations = {
    "Pyno.app": (180, 190),
    "Applications": (480, 190),
    "OPEN ME FIRST.txt": (330, 70),
}
hide_extension = ["Pyno.app"]
SETTINGS

echo "==> Creating disk image"
"$VENV/bin/dmgbuild" -s "$WORK/settings.py" \
  -D app="$APP" \
  -D notice="$NOTICE" \
  -D volume_icon="Resources/AppIcon.icns" \
  -D background="$WORK/background.tiff" \
  "Pyno" "$DMG" >/dev/null

rm -rf "$WORK"

# Notarization accepts an unsigned disk image, but a signed one also survives being
# renamed or re-hosted, so sign it whenever an identity is available.
if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "==> Signing the disk image"
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  codesign --verify --verbose=2 "$DMG"
fi

echo "Done: $DMG ($(du -h "$DMG" | cut -f1))"
