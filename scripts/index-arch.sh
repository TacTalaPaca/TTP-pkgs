#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

main() {
  auto_key
  require_cmd repo-add
  if [[ -n "${KEY_ID:-}" ]]; then require_cmd gpg; fi

  local root="$REPO_DIR/arch"
  local -a archdirs=()
  mapfile -t archdirs < <(
    find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null | sort
  )

  if [[ ${#archdirs[@]} -eq 0 ]]; then
    warn "no Arch architecture directories under ${root#$ROOT_DIR/}; skipping Arch index"
    return 0
  fi

  local dir arch db files pkg
  for dir in "${archdirs[@]}"; do
    arch="$(basename "$dir")"
    db="$dir/$REPO_NAME.db.tar.zst"
    files="$dir/$REPO_NAME.files.tar.zst"

    local -a pkgs=()
    while IFS= read -r pkg; do pkgs+=("$pkg"); done < <(
      find "$dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' | sort
    )

    if [[ ${#pkgs[@]} -eq 0 ]]; then
      warn "no Arch packages under ${dir#$ROOT_DIR/}; skipping"
      continue
    fi

    log "Building Arch index for $arch (${#pkgs[@]} package(s))"

    # Full rebuild so removed/renamed packages cannot linger in the database.
    rm -f \
      "$dir/$REPO_NAME.db" "$dir/$REPO_NAME.db.sig" \
      "$dir/$REPO_NAME.files" "$dir/$REPO_NAME.files.sig" \
      "$dir/$REPO_NAME.db.tar."* "$dir/$REPO_NAME.db.tar."*.sig \
      "$dir/$REPO_NAME.files.tar."* "$dir/$REPO_NAME.files.tar."*.sig

    if [[ -n "${KEY_ID:-}" ]]; then
      repo-add -q -s -k "$KEY_ID" "$db" "${pkgs[@]}"
    else
      repo-add -q "$db" "${pkgs[@]}"
    fi

    # Cloudflare R2 (and any static host) cannot serve symlinks. Replace the
    # repo-add symlinks with real files under the names pacman actually fetches.
    rm -f "$dir/$REPO_NAME.db" "$dir/$REPO_NAME.db.sig" \
          "$dir/$REPO_NAME.files" "$dir/$REPO_NAME.files.sig"
    cp -f "$db" "$dir/$REPO_NAME.db"
    [[ -f "$db.sig" ]] && cp -f "$db.sig" "$dir/$REPO_NAME.db.sig"
    if [[ -f "$files" ]]; then
      cp -f "$files" "$dir/$REPO_NAME.files"
      [[ -f "$files.sig" ]] && cp -f "$files.sig" "$dir/$REPO_NAME.files.sig"
    fi

    info "database: $(tar -tf "$db" 2>/dev/null | grep -c '/desc$') package(s)"
    if [[ -n "${KEY_ID:-}" ]]; then info "signed database"; fi
  done
}

main "$@"
