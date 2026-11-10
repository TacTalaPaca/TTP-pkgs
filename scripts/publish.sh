#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [PACKAGE_DIR ...]

Copies .deb / .rpm / .pkg.tar.* files from PACKAGE_DIR (default:
packages/<app>/<version>/) into repo/, rebuilds the APT, RPM and pacman
indexes, signs packages and metadata, regenerates README.md, and optionally
uploads the repository to Cloudflare R2.

Options:
  --sync       upload repo/ to Cloudflare R2 when done
  --no-sync    do not upload (default)
  --unsigned   skip GPG signing (local testing only)
  -h, --help   show this help

Examples:
  ./scripts/publish.sh
  ./scripts/publish.sh packages/firegila/0.1.3
  ./scripts/publish.sh --sync
EOF
}

_copy_deb() {
  local f=$1 pkg arch dest
  pkg="$(dpkg-deb -f "$f" Package)"
  arch="$(dpkg-deb -f "$f" Architecture)"
  [[ -n "$pkg" ]] || die "cannot read Package from $f"
  [[ -n "$arch" ]] || die "cannot read Architecture from $f"
  dest="$REPO_DIR/apt/pool/$APT_COMPONENT/${pkg:0:1}/$pkg"
  mkdir -p "$dest"
  cp -f "$f" "$dest/"
  info "deb   $(basename "$f") -> ${dest#"$ROOT_DIR"/}/"
}

_copy_rpm() {
  local f=$1 arch dest
  arch="$(rpm -qp --qf '%{ARCH}' "$f" 2>/dev/null || true)"
  [[ -n "$arch" && "$arch" != "(none)" ]] || arch=x86_64
  [[ "$arch" == "noarch" ]] && arch=x86_64
  dest="$REPO_DIR/rpm/$arch"
  mkdir -p "$dest"
  cp -f "$f" "$dest/"
  info "rpm   $(basename "$f") -> ${dest#"$ROOT_DIR"/}/"
}

_copy_arch() {
  local f=$1 arch dest
  arch="$(pacman -Qip "$f" 2>/dev/null \
    | awk -F': ' '/^Architecture[[:space:]]*:/{print $2; exit}')"
  [[ -n "$arch" && "$arch" != "any" ]] || arch=x86_64
  dest="$REPO_DIR/arch/$arch"
  mkdir -p "$dest"
  cp -f "$f" "$dest/"
  info "arch  $(basename "$f") -> ${dest#"$ROOT_DIR"/}/"
}

_render() {
  local src=$1 dst=$2 mode=$3
  sed \
    -e "s|@BASE_URL@|$BASE_URL|g" \
    -e "s|@REPO_NAME@|$REPO_NAME|g" \
    -e "s|@REPO_TITLE@|$REPO_TITLE|g" \
    -e "s|@KEY_FPR@|${KEY_ID:-}|g" \
    -e "s|@APT_SUITE@|$APT_SUITE|g" \
    -e "s|@APT_COMPONENT@|$APT_COMPONENT|g" \
    "$src" > "$dst"
  chmod "$mode" "$dst"
}

_render_setup() {
  if [[ -f "$KEY_FILE" ]]; then
    install -m 0644 "$KEY_FILE" "$REPO_DIR/keys/$REPO_NAME.asc"
  fi

  _render "$SETUP_DIR/install.sh.in"   "$REPO_DIR/setup/install.sh"   0755
  _render "$SETUP_DIR/uninstall.sh.in" "$REPO_DIR/setup/uninstall.sh" 0755
  _render "$SETUP_DIR/$REPO_NAME.repo.in" "$REPO_DIR/rpm/$REPO_NAME.repo" 0644
}

main() {
  local sync=0 unsigned=0
  local -a sources=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sync)     sync=1; shift ;;
      --no-sync)  sync=0; shift ;;
      --unsigned) unsigned=1; shift ;;
      -h|--help)  usage; exit 0 ;;
      -*)         die "unknown option: $1 (try --help)" ;;
      *)          sources+=("$1"); shift ;;
    esac
  done

  export UNSIGNED="$unsigned"

  require_cmd dpkg-deb
  require_cmd rpm
  require_cmd pacman
  require_cmd sed

  if [[ "$unsigned" -eq 1 ]]; then
    KEY_ID=""
    export KEY_ID
    warn "signing disabled (--unsigned): this is for local testing only"
  else
    resolve_key
  fi

  ensure_repo_dirs

  if [[ ${#sources[@]} -eq 0 ]]; then
    mapfile -t sources < <(
      find "$PACKAGES_DIR" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort
    )
  fi

  [[ ${#sources[@]} -gt 0 ]] || die "no package directories found (expected e.g. packages/<app>/<version>/)"

  local src f copied=0
  for src in "${sources[@]}"; do
    [[ -d "$src" ]] || die "not a directory: $src"
    log "Adding ${src#"$ROOT_DIR"/}"
    for f in "$src"/*; do
      [[ -f "$f" ]] || continue
      case "$f" in
        *.deb)                                    _copy_deb  "$f"; copied=$((copied + 1)) ;;
        *.rpm)                                    _copy_rpm  "$f"; copied=$((copied + 1)) ;;
        *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz)  _copy_arch "$f"; copied=$((copied + 1)) ;;
        *) info "ignored $(basename "$f")" ;;
      esac
    done
  done

  [[ "$copied" -gt 0 ]] || die "no supported packages found (.deb, .rpm, .pkg.tar.*)"

  log "Rebuilding indexes"
  "$SCRIPT_DIR/index-apt.sh"
  "$SCRIPT_DIR/index-rpm.sh"
  "$SCRIPT_DIR/index-arch.sh"

  log "Rendering install scripts and README"
  _render_setup
  "$SCRIPT_DIR/gen-readme.sh"

  if [[ "$sync" -eq 1 ]]; then
    "$SCRIPT_DIR/sync-r2.sh"
  else
    log "skipping R2 upload (use --sync to publish)"
  fi

  cat <<EOF

Repository built in ${REPO_DIR#"$ROOT_DIR"/}/.

  APT:    ${BASE_URL}/apt
  RPM:    ${BASE_URL}/rpm/$REPO_NAME.repo
  pacman: ${BASE_URL}/arch/\$arch
  Setup:  ${BASE_URL}/setup/install.sh

EOF
}

main "$@"
