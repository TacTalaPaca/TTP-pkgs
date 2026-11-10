#!/usr/bin/env bash
# Cache the GPG passphrase in gpg-agent for the current session so publish.sh
# can sign without prompting. Safe to run repeatedly.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmd gpg

KEY_ID="$(detect_key_id || true)"
[[ -n "$KEY_ID" ]] || die "no public key found at $KEY_FILE; run scripts/init-key.sh first"

KEYGRIP="$(gpg --with-keygrip --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null \
  | awk -F: '/^grp:/{print $10; exit}')"
[[ -n "$KEYGRIP" ]] || die "no secret key for $KEY_ID"

PRESET="$(command -v gpg-preset-passphrase || true)"
[[ -n "$PRESET" ]] || PRESET=/usr/lib/gnupg/gpg-preset-passphrase
[[ -x "$PRESET" ]] || die "gpg-preset-passphrase not found"

AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
mkdir -p "$HOME/.gnupg"
if ! grep -qs '^allow-preset-passphrase' "$AGENT_CONF"; then
  printf 'allow-preset-passphrase\ndefault-cache-ttl 7200\nmax-cache-ttl 28800\n' >> "$AGENT_CONF"
  chmod 600 "$AGENT_CONF"
  gpgconf --kill gpg-agent 2>/dev/null || true
fi

if command -v zenity >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  PASS="$(zenity --password --title="Unlock TTP-pkgs signing key" \
    --text="Enter the GPG passphrase for the TTP-pkgs signing key")" \
    || die "passphrase dialog cancelled"
else
  read -r -s -p "GPG passphrase: " PASS
  echo
fi
[[ -n "$PASS" ]] || die "passphrase cannot be empty"

printf '%s' "$PASS" | "$PRESET" --preset "$KEYGRIP"
unset PASS

log "Signing key unlocked for this session (cached for up to 8 hours)"
