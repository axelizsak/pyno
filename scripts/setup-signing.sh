#!/usr/bin/env bash
# One-time setup of everything needed to ship a signed, notarized Pyno.
#
#   ./scripts/setup-signing.sh status          what is already in place
#   ./scripts/setup-signing.sh csr             make the key + signing request
#   ./scripts/setup-signing.sh import <.cer>   install the certificate Apple gave back
#   ./scripts/setup-signing.sh notary          store the notarization password
#   ./scripts/setup-signing.sh notary-key <.p8> store an App Store Connect API key
#
# The private key lives in ~/.pyno-signing and never enters the repository.
set -euo pipefail

KEYDIR="$HOME/.pyno-signing"
KEY="$KEYDIR/developer-id.key"
CSR="$KEYDIR/developer-id.csr"
DESKTOP_CSR="$HOME/Desktop/pyno-developer-id.csr"
NOTARY_PROFILE="${NOTARY_PROFILE:-pyno-notary}"
LOGIN_KEYCHAIN="$(security default-keychain | tr -d ' "')"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" \
    | head -1 \
    | sed 's/.*"\(.*\)"/\1/'
}

cmd_status() {
  bold "Signing identity"
  local id; id="$(identity || true)"
  if [ -n "$id" ]; then
    echo "  ok  $id"
  else
    echo "  --  no Developer ID Application certificate in the keychain"
  fi

  bold "Notarization credentials"
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "  ok  keychain profile '$NOTARY_PROFILE'"
  else
    echo "  --  no keychain profile '$NOTARY_PROFILE'"
  fi

  bold "Signing request"
  if [ -f "$CSR" ]; then echo "  ok  $CSR"; else echo "  --  not generated yet"; fi

  if [ -n "$id" ]; then
    echo
    echo "Ready. Release with:"
    echo "  DEVELOPER_ID=\"$id\" ./scripts/release.sh"
  fi
}

cmd_csr() {
  mkdir -p "$KEYDIR"
  chmod 700 "$KEYDIR"

  if [ -f "$KEY" ]; then
    echo "Key already exists at $KEY — reusing it."
  else
    echo "==> Generating a 2048-bit private key"
    openssl genrsa -out "$KEY" 2048 2>/dev/null
    chmod 600 "$KEY"
  fi

  local name email
  name="${SIGNING_NAME:-$(id -F 2>/dev/null || id -un)}"
  email="${SIGNING_EMAIL:-$(git config user.email 2>/dev/null || echo "")}"
  [ -n "$email" ] || { echo "error: set SIGNING_EMAIL to your Apple ID email" >&2; exit 1; }

  echo "==> Generating the certificate signing request"
  openssl req -new -key "$KEY" -out "$CSR" \
    -subj "/emailAddress=$email/CN=$name/C=US" 2>/dev/null
  chmod 600 "$CSR"

  # The keys live in a dot-directory, which Finder hides from the upload dialog.
  # The request holds nothing secret, so put a copy somewhere draggable.
  cp "$CSR" "$DESKTOP_CSR"

  echo
  bold "Next, on developer.apple.com (about two minutes)"
  cat <<INSTRUCTIONS
  1. Open https://developer.apple.com/account/resources/certificates/add
  2. Choose "Developer ID Application", then Continue.
     If asked about the profile type, choose "G2 Sub-CA (Xcode 11.4.1 or later)".
  3. Upload the copy left on your desktop:
       $DESKTOP_CSR
  4. Continue, then Download. You get developerID_application.cer.
  5. Come back and run:
       ./scripts/setup-signing.sh import ~/Downloads/developerID_application.cer
INSTRUCTIONS
  echo
  echo "Revealing it in Finder…"
  open -R "$DESKTOP_CSR" 2>/dev/null || true
}

cmd_import() {
  local cer="${1:-}"
  [ -n "$cer" ] || { echo "usage: setup-signing.sh import <developerID_application.cer>" >&2; exit 1; }
  [ -f "$cer" ] || { echo "error: $cer not found" >&2; exit 1; }
  [ -f "$KEY" ] || { echo "error: $KEY missing — run 'setup-signing.sh csr' first" >&2; exit 1; }

  echo "==> Installing Apple's intermediate certificates"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  for ca in DeveloperIDG2CA AppleWWDRCAG3; do
    if curl -fsSL "https://www.apple.com/certificateauthority/$ca.cer" -o "$tmp/$ca.cer"; then
      security import "$tmp/$ca.cer" -k "$LOGIN_KEYCHAIN" 2>/dev/null || true
    fi
  done

  echo "==> Importing the private key"
  security import "$KEY" -k "$LOGIN_KEYCHAIN" \
    -T /usr/bin/codesign -T /usr/bin/security 2>/dev/null || true

  echo "==> Importing the certificate"
  # Downloading a .cer in Safari, or double-clicking it, already files it in the
  # keychain. That makes a second import a duplicate, which is fine — what matters
  # is the identity check below, not who put the certificate there.
  security import "$cer" -k "$LOGIN_KEYCHAIN" -T /usr/bin/codesign 2>&1 \
    | grep -v "already exists in the keychain" || true

  echo "==> Allowing codesign to use the key"
  if ! security set-key-partition-list -S apple-tool:,apple:,codesign: \
       -s -k "" "$LOGIN_KEYCHAIN" >/dev/null 2>&1; then
    echo "    macOS will ask once, on the first signature. Click Always Allow."
  fi

  rm -f "$DESKTOP_CSR"

  echo
  local id; id="$(identity || true)"
  if [ -n "$id" ]; then
    bold "Done: $id"
    echo
    echo "Now store the notarization password:"
    echo "  ./scripts/setup-signing.sh notary"
  else
    echo "error: the certificate imported but no usable identity appeared." >&2
    echo "Check that the key and the certificate are the matching pair." >&2
    exit 1
  fi
}

cmd_notary() {
  local apple_id team_id
  apple_id="${APPLE_ID:-${SIGNING_EMAIL:-}}"
  team_id="${TEAM_ID:-}"

  if [ -z "$team_id" ]; then
    local id; id="$(identity || true)"
    team_id="$(printf '%s' "$id" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')"
  fi

  [ -n "$apple_id" ] || { echo "error: set APPLE_ID to your Apple ID email" >&2; exit 1; }
  [ -n "$team_id" ] || { echo "error: set TEAM_ID (10 characters, from developer.apple.com > Membership)" >&2; exit 1; }

  bold "App-specific password"
  cat <<INSTRUCTIONS
  Notarization will not accept your normal Apple password. It wants an
  app-specific one, from https://account.apple.com
    > Sign-In and Security > App-Specific Passwords > +

  It looks like abcd-efgh-ijkl-mnop. Paste it whole, dashes included. Nothing
  echoes as you type, and it is shown once — if you closed that panel, the old
  one is unrecoverable and you need a new one.

  If this keeps failing, use an App Store Connect API key instead:
    ./scripts/setup-signing.sh notary-key ~/Downloads/AuthKey_XXXXXXXXXX.p8

INSTRUCTIONS
  xcrun notarytool store-credentials "$NOTARY_PROFILE" \
    --apple-id "$apple_id" --team-id "$team_id"

  echo
  bold "Stored as keychain profile '$NOTARY_PROFILE'."
  cmd_status
}

cmd_notary_key() {
  local key="${1:-}"
  [ -n "$key" ] || { echo "usage: setup-signing.sh notary-key <AuthKey_XXXXXXXXXX.p8>" >&2; exit 1; }
  [ -f "$key" ] || { echo "error: $key not found" >&2; exit 1; }

  local key_id issuer
  # The file Apple hands you is named AuthKey_<the key id>.p8.
  key_id="${KEY_ID:-$(basename "$key" | sed -n 's/^AuthKey_\(.*\)\.p8$/\1/p')}"
  issuer="${ISSUER:-}"

  if [ -z "$key_id" ]; then
    read -r -p "Key ID (10 characters, shown next to the key): " key_id
  fi
  if [ -z "$issuer" ]; then
    echo "The Issuer ID is a UUID at the top of the Integrations > Keys page."
    read -r -p "Issuer ID: " issuer
  fi

  xcrun notarytool store-credentials "$NOTARY_PROFILE" \
    --key "$key" --key-id "$key_id" --issuer "$issuer"

  echo
  bold "Stored as keychain profile '$NOTARY_PROFILE'."
  cmd_status
}

case "${1:-status}" in
  status) cmd_status ;;
  csr)    cmd_csr ;;
  import) shift; cmd_import "${1:-}" ;;
  notary) cmd_notary ;;
  notary-key) shift; cmd_notary_key "${1:-}" ;;
  *) echo "usage: setup-signing.sh [status|csr|import <.cer>|notary|notary-key <.p8>]" >&2; exit 1 ;;
esac
