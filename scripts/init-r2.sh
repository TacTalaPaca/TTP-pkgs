#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

require_cmd rclone

cat <<EOF
Configure the Cloudflare R2 remote used to publish ${BASE_URL}.

You need three values from the Cloudflare dashboard:
  * Account ID            (R2 -> Overview, right-hand sidebar)
  * Access Key ID         (R2 -> Manage R2 API Tokens -> Object Read & Write)
  * Secret Access Key     (shown once when the token is created)

rclone stores these in ~/.config/rclone/rclone.conf (mode 600), not in this repo.

EOF

read -r -p "Cloudflare Account ID: " ACCOUNT_ID
read -r -p "R2 Access Key ID: " ACCESS_KEY
read -r -s -p "R2 Secret Access Key: " SECRET_KEY
echo

[[ -n "$ACCOUNT_ID" ]] || die "Account ID cannot be empty"
[[ -n "$ACCESS_KEY" ]] || die "Access Key ID cannot be empty"
[[ -n "$SECRET_KEY" ]] || die "Secret Access Key cannot be empty"

log "Writing rclone remote '$R2_REMOTE'"
rclone config create "$R2_REMOTE" s3 \
  provider Cloudflare \
  access_key_id "$ACCESS_KEY" \
  secret_access_key "$SECRET_KEY" \
  endpoint "https://${ACCOUNT_ID}.r2.cloudflarestorage.com" \
  region auto \
  acl private \
  >/dev/null

if [[ -f "$HOME/.config/rclone/rclone.conf" ]]; then
  chmod 600 "$HOME/.config/rclone/rclone.conf"
fi

log "Testing access to bucket '$R2_BUCKET'"
if rclone lsd "${R2_REMOTE}:${R2_BUCKET}" >/dev/null 2>&1; then
  info "OK: bucket is reachable"
else
  warn "could not list ${R2_REMOTE}:${R2_BUCKET}"
  warn "Check that the bucket exists and the token has Object Read & Write on it."
fi

cat <<EOF

Done. Publish with:

  ./scripts/publish.sh --sync

Check the public URL afterwards:

  curl -I ${BASE_URL}/setup/install.sh

EOF
