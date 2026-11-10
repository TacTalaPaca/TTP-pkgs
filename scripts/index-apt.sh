#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# Emit one checksum section for the APT Release file.
_release_sums() {
  local dir=$1 label=$2 cmd=$3 rel hash size

  printf '%s:\n' "$label"
  while IFS= read -r rel; do
    hash="$("$cmd" "$dir/$rel" | awk '{print $1}')"
    size="$(stat -c%s "$dir/$rel")"
    printf ' %s %16d %s\n' "$hash" "$size" "$rel"
  done < <(
    cd "$dir" &&
      find . -type f \
        ! -name Release ! -name InRelease ! -name Release.gpg \
        -printf '%P\n' | sort
  )
}

main() {
  auto_key
  require_cmd dpkg-deb
  require_cmd dpkg-scanpackages
  require_cmd gzip
  if [[ -n "${KEY_ID:-}" ]]; then require_cmd gpg; fi

  local apt_dir="$REPO_DIR/apt"
  local pool="$apt_dir/pool/$APT_COMPONENT"
  local dist="$apt_dir/dists/$APT_SUITE"
  local deb arch

  mapfile -t debs < <(find "$pool" -type f -name '*.deb' 2>/dev/null | sort)
  if [[ ${#debs[@]} -eq 0 ]]; then
    warn "no .deb files under ${pool#$ROOT_DIR/}; skipping APT index"
    return 0
  fi

  log "Building APT index (${#debs[@]} .deb file(s))"
  rm -rf "$apt_dir/dists"

  # Which architectures are actually present? "all" is implied by dpkg-scanpackages.
  declare -A arches=()
  for deb in "${debs[@]}"; do
    arch="$(dpkg-deb -f "$deb" Architecture)"
    [[ -n "$arch" ]] || die "cannot read Architecture from $deb"
    [[ "$arch" == "all" ]] || arches["$arch"]=1
  done
  if [[ ${#arches[@]} -eq 0 ]]; then
    arches["all"]=1
  fi

  local outdir
  for arch in "${!arches[@]}"; do
    outdir="$dist/$APT_COMPONENT/binary-$arch"
    mkdir -p "$outdir"
    (
      cd "$apt_dir"
      dpkg-scanpackages --arch "$arch" -m "pool/$APT_COMPONENT" /dev/null \
        > "$outdir/Packages"
    )
    gzip -9n -c "$outdir/Packages" > "$outdir/Packages.gz"
    info "binary-$arch: $(grep -c '^Package:' "$outdir/Packages") package(s)"
  done

  local arch_list
  arch_list="$(printf '%s\n' "${!arches[@]}" | sort | paste -sd' ' -)"

  local release="$dist/Release"
  {
    printf 'Origin: %s\n' "$ORIGIN"
    printf 'Label: %s\n' "$REPO_TITLE"
    printf 'Suite: %s\n' "$APT_SUITE"
    printf 'Codename: %s\n' "$APT_SUITE"
    printf 'Version: 1.0\n'
    printf 'Architectures: %s\n' "$arch_list"
    printf 'Components: %s\n' "$APT_COMPONENT"
    printf 'Description: %s package repository\n' "$REPO_TITLE"
    printf 'Date: %s\n' "$(LC_ALL=C date -Ru)"
    _release_sums "$dist" MD5Sum md5sum
    _release_sums "$dist" SHA1 sha1sum
    _release_sums "$dist" SHA256 sha256sum
    _release_sums "$dist" SHA512 sha512sum
  } > "$release"

  if [[ -n "${KEY_ID:-}" ]]; then
    gpg --batch --yes --local-user "$KEY_ID" \
      --clearsign --output "$dist/InRelease" "$release"
    gpg --batch --yes --local-user "$KEY_ID" \
      --armor --detach-sign --output "$dist/Release.gpg" "$release"
    info "signed Release (key $KEY_ID)"
  else
    warn "APT metadata left unsigned (--unsigned)"
  fi
}

main "$@"
