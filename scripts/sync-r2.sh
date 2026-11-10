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

  # Set caching on the objects themselves so indexes are never stale.
  # rclone sync removes files that no longer exist in repo/.
  rclone sync "$REPO_DIR" "${R2_REMOTE}:${R2_BUCKET}" \
    --copy-links \
    --checksum \
    --transfers "${R2_TRANSFERS:-8}" \
    --checkers "${R2_CHECKERS:-16}" \
    --header-upload "Cache-Control: no-cache" \
    --stats-one-line \
    --stats 10s
}

main "$@"
