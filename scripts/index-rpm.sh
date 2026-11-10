#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

main() {
  auto_key
  require_cmd createrepo_c
  if [[ -n "${KEY_ID:-}" ]]; then
    require_cmd gpg
    require_cmd rpmsign
  fi

  local root="$REPO_DIR/rpm"
  local -a archdirs=()
  mapfile -t archdirs < <(
    find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null | sort
  )

  if [[ ${#archdirs[@]} -eq 0 ]]; then
    warn "no RPM architecture directories under ${root#$ROOT_DIR/}; skipping RPM index"
    return 0
  fi

  local dir arch rpm primary
  for dir in "${archdirs[@]}"; do
    arch="$(basename "$dir")"

    local -a rpms=()
    while IFS= read -r rpm; do rpms+=("$rpm"); done < <(
      find "$dir" -maxdepth 1 -type f -name '*.rpm' | sort
    )

    if [[ ${#rpms[@]} -eq 0 ]]; then
      warn "no .rpm files under ${dir#$ROOT_DIR/}; skipping"
      continue
    fi

    log "Building RPM index for $arch (${#rpms[@]} package(s))"

    if [[ -n "${KEY_ID:-}" ]]; then
      for rpm in "${rpms[@]}"; do
        if ! rpmsign --addsign --key-id "$KEY_ID" "$rpm" >/dev/null 2>&1; then
          warn "failed to sign ${rpm#$ROOT_DIR/}"
        fi
      done
    fi

    rm -rf "$dir/repodata"
    createrepo_c --quiet --no-database \
      --checksum sha256 \
      --compress-type gz --general-compress-type gz \
      "$dir"

    primary="$(find "$dir/repodata" -maxdepth 1 -name '*primary.xml.gz' | head -n1)"
    if [[ -n "$primary" ]]; then
      info "repodata: $(zcat "$primary" | grep -c '<package ') package(s)"
    fi

    if [[ -n "${KEY_ID:-}" ]]; then
      gpg --batch --yes --local-user "$KEY_ID" --armor --detach-sign \
        --output "$dir/repodata/repomd.xml.asc" "$dir/repodata/repomd.xml"
      info "signed repomd.xml"
    fi
  done
}

main "$@"
