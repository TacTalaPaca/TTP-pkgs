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

# Reuse an existing secret key with the same UID if there is one.
FPR="$(gpg --list-secret-keys --with-colons "$KEY_UID" 2>/dev/null \
  | awk -F: '/^fpr:/{print $10; exit}' || true)"

if [[ -n "$FPR" ]]; then
  log "Using existing signing key: $FPR"
else
  log "Creating $KEY_ALGO signing key for: $KEY_UID"
  info "You will be asked for a passphrase. Use a long one and store it safely."
  gpg --quick-gen-key "$KEY_UID" "$KEY_ALGO" sign "$KEY_EXPIRE"

  FPR="$(gpg --list-secret-keys --with-colons "$KEY_UID" 2>/dev/null \
    | awk -F: '/^fpr:/{print $10; exit}' || true)"
  [[ -n "$FPR" ]] || die "key generation failed"
fi

gpg --armor --export "$FPR" > "$KEY_FILE"
chmod 0644 "$KEY_FILE"

cat <<EOF

$(log "Public key written: ${KEY_FILE#$ROOT_DIR/}")

  Fingerprint: $FPR

Next steps:
  1. Back up the PRIVATE key offline (then delete the file):
       gpg --armor --export-secret-keys $FPR > ~/ttp-pkgs-private-key.asc

  2. Configure Cloudflare R2:
       ./scripts/init-r2.sh

  3. Publish your first packages:
       ./scripts/publish.sh --sync

EOF
