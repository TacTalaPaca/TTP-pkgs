#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

main() {
  require_cmd rclone

  [[ -d "$REPO_DIR" ]] || die "repo/ does not exist yet; run scripts/publish.sh first"
  find "$REPO_DIR" -type f -print -quit | grep -q . \
    || die "repo/ is empty; run scripts/publish.sh first"

  log "Uploading ${REPO_DIR#"$ROOT_DIR"/}/ -> ${R2_REMOTE}:${R2_BUCKET}"
  info "rclone sync --copy-links --checksum --delete"

  # The custom domain is proxied by Cloudflare. Set Cache-Control on the objects
  # themselves (bucket-scoped, no zone-wide Cache Rule) so InRelease, repomd.xml
  # and ttp-pkgs.db are never served stale. R2 egress is free, so revalidation
  # has no cost.
  rclone sync "$REPO_DIR" "${R2_REMOTE}:${R2_BUCKET}" \
    --copy-links \
    --checksum \
    --delete \
    --transfers "${R2_TRANSFERS:-8}" \
    --checkers "${R2_CHECKERS:-16}" \
    --header-upload "Cache-Control: no-cache" \
    --stats-one-line \
    --stats 10s

  cat <<EOF

Published:

  ${BASE_URL}/setup/install.sh
  ${BASE_URL}/apt/dists/${APT_SUITE}/InRelease
  ${BASE_URL}/rpm/${REPO_NAME}.repo
  ${BASE_URL}/arch/\$arch/${REPO_NAME}.db

EOF
}

main "$@"
