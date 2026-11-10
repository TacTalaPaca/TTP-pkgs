#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

TMP_LIST=""
cleanup() {
  [[ -n "$TMP_LIST" ]] && rm -f "$TMP_LIST"
  return 0
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage: $(basename "$0") [--yes] <package> <keep-count>

Removes all but the newest <keep-count> versions of <package> from both
packages/ and repo/. Without --yes it only prints what would be deleted.

After pruning, rebuild and upload with:

  ./scripts/publish.sh --sync
EOF
}

_upstream_version() {
  # 0.1.3-1 -> 0.1.3 (works for deb revisions and Arch pkgrel)
  printf '%s\n' "${1%-[0-9]*}"
}

_describe() {
  local f=$1
  case "$f" in
    *.deb)
      printf '%s\t%s\n' \
        "$(dpkg-deb -f "$f" Package 2>/dev/null || true)" \
        "$(dpkg-deb -f "$f" Version 2>/dev/null || true)"
      ;;
    *.rpm)
      printf '%s\t%s\n' \
        "$(rpm -qp --qf '%{NAME}' "$f" 2>/dev/null || true)" \
        "$(rpm -qp --qf '%{VERSION}' "$f" 2>/dev/null || true)"
      ;;
    *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz)
      printf '%s\t%s\n' \
        "$(pacman -Qip "$f" 2>/dev/null | awk -F': ' '/^Name[[:space:]]*:/{print $2; exit}')" \
        "$(pacman -Qip "$f" 2>/dev/null | awk -F': ' '/^Version[[:space:]]*:/{print $2; exit}')"
      ;;
  esac
}

main() {
  local yes=0 pkg keep

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes=1; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option: $1" ;;
      *) break ;;
    esac
  done

  [[ $# -eq 2 ]] || { usage; exit 1; }
  pkg=$1
  keep=$2
  [[ "$keep" =~ ^[0-9]+$ ]] || die "keep-count must be a number"
  [[ "$keep" -ge 1 ]] || die "keep-count must be at least 1"

  require_cmd dpkg-deb
  require_cmd rpm
  require_cmd pacman

  TMP_LIST="$(mktemp)"

  local f name ver
  while IFS= read -r f; do
    IFS=$'\t' read -r name ver < <(_describe "$f")
    [[ -n "$name" && -n "$ver" && "$name" == "$pkg" ]] || continue
    printf '%s\t%s\n' "$f" "$(_upstream_version "$ver")" >> "$TMP_LIST"
  done < <(
    find "$PACKAGES_DIR" "$REPO_DIR" -type f \
      \( -name '*.deb' -o -name '*.rpm' -o -name '*.pkg.tar.*' \) \
      ! -name '*.sig' 2>/dev/null | sort
  )

  [[ -s "$TMP_LIST" ]] || die "no packages named '$pkg' found"

  local keep_versions
  keep_versions="$(cut -f2 "$TMP_LIST" | sort -V | uniq | tail -n "$keep")"

  local removed=0
  while IFS=$'\t' read -r f ver; do
    if grep -Fxq "$ver" <<< "$keep_versions"; then
      continue
    fi
    if [[ "$yes" -eq 1 ]]; then
      rm -f "$f" "$f.sig"
      info "removed ${f#"$ROOT_DIR"/}"
    else
      info "would remove ${f#"$ROOT_DIR"/}"
    fi
    removed=$((removed + 1))
  done < "$TMP_LIST"

  if [[ "$removed" -eq 0 ]]; then
    log "nothing to prune; '$pkg' already has $keep or fewer versions"
    return 0
  fi

  if [[ "$yes" -eq 1 ]]; then
    log "removed $removed file(s). Now run: ./scripts/publish.sh --sync"
  else
    log "dry run: $removed file(s) would be removed. Re-run with --yes."
  fi
}

main "$@"
