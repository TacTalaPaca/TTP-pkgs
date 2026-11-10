#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

KEY_UID="${KEY_UID:-TTP pkgs Packages <packages@tactalapaca.com>}"
KEY_ALGO="${KEY_ALGO:-rsa4096}"
KEY_EXPIRE="${KEY_EXPIRE:-2y}"

require_cmd gpg
mkdir -p "$KEYS_DIR"

# Use the normal pinentry in a terminal; otherwise ask with zenity and use
# gpg's loopback mode.
_quick_gen_key() {
  if [[ -t 0 ]]; then
    gpg --quick-gen-key "$KEY_UID" "$KEY_ALGO" sign "$KEY_EXPIRE"
    return 0
  fi

  command -v zenity >/dev/null 2>&1 \
    || die "no TTY and zenity is unavailable; run this script from a terminal"

  local p1 p2
  p1="$(zenity --password --title="TTP-pkgs signing key" \
        --text="Choose a passphrase for the TTP-pkgs signing key")" \
    || die "passphrase dialog cancelled"
  [[ -n "$p1" ]] || die "passphrase cannot be empty"

  p2="$(zenity --password --title="Confirm passphrase" \
        --text="Repeat the passphrase")" \
    || die "passphrase dialog cancelled"
  [[ "$p1" == "$p2" ]] || die "passphrases do not match"

  printf '%s' "$p1" | gpg --batch --pinentry-mode loopback --passphrase-fd 0 \
    --quick-gen-key "$KEY_UID" "$KEY_ALGO" sign "$KEY_EXPIRE"
}

_fingerprint() {
  gpg --list-secret-keys --with-colons "$KEY_UID" 2>/dev/null \
    | awk -F: '/^fpr:/{print $10; exit}'
}

# Reuse an existing secret key with the same UID if there is one.
FPR="$(_fingerprint || true)"

if [[ -n "$FPR" ]]; then
  log "Using existing signing key: $FPR"
else
  log "Creating $KEY_ALGO signing key for: $KEY_UID"
  info "You will be asked for a passphrase. Use a long one and store it safely."
  _quick_gen_key
  FPR="$(_fingerprint || true)"
  [[ -n "$FPR" ]] || die "key generation failed"
fi

gpg --armor --export "$FPR" > "$KEY_FILE"
chmod 0644 "$KEY_FILE"

log "Public key written: ${KEY_FILE#$ROOT_DIR/}"
cat <<EOF

  Fingerprint: $FPR

Back up the private key offline:
  gpg --armor --export-secret-keys $FPR > ~/ttp-pkgs-private-key.asc

Next:
  ./scripts/init-r2.sh          # only if rclone is not configured
  ./scripts/publish.sh --sync

EOF
