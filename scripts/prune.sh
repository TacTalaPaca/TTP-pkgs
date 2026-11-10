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
Usage:
  $(basename "$0") [--yes] [--repo-only] <package> <keep-count>
  $(basename "$0") [--yes] [--repo-only] --all --keep <keep-count>

Removes all but the newest <keep-count> versions. By default it scans both
packages/ and repo/; --repo-only scans only the published repo.

Without --yes it only prints what would be deleted.
EOF
}

_upstream_version() {
  # 0.1.3-1 -> 0.1.3
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
        "$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$f" 2>/dev/null || true)"
      ;;
    *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz)
      printf '%s\t%s\n' \
        "$(pacman -Qip "$f" 2>/dev/null | awk -F': ' '/^Name[[:space:]]*:/{print $2; exit}')" \
        "$(pacman -Qip "$f" 2>/dev/null | awk -F': ' '/^Version[[:space:]]*:/{print $2; exit}')"
      ;;
  esac
}

main() {
  local yes=0 repo_only=0 all=0 keep=""
  local -a names=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) yes=1; shift ;;
      --repo-only) repo_only=1; shift ;;
      --all) all=1; shift ;;
      --keep) keep=$2; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option: $1" ;;
      *) break ;;
    esac
  done

  if [[ "$all" -eq 1 ]]; then
    [[ -n "$keep" ]] || die "--all requires --keep <count>"
    [[ $# -eq 0 ]] || die "unexpected arguments: $*"
  else
    [[ $# -eq 2 ]] || { usage; exit 1; }
    keep=$2
    names=("$1")
  fi

  [[ "$keep" =~ ^[0-9]+$ ]] || die "keep-count must be a number"
  [[ "$keep" -ge 1 ]] || die "keep-count must be at least 1"

  require_cmd dpkg-deb
  require_cmd rpm
  require_cmd pacman

  local -a roots=("$REPO_DIR")
  if [[ "$repo_only" -eq 0 ]]; then
    roots=("$PACKAGES_DIR" "$REPO_DIR")
  fi

  TMP_LIST="$(mktemp)"

  local f name ver
  while IFS= read -r f; do
    IFS=$'\t' read -r name ver < <(_describe "$f")
    [[ -n "$name" && -n "$ver" ]] || continue
    printf '%s\t%s\t%s\n' "$f" "$name" "$(_upstream_version "$ver")" >> "$TMP_LIST"
  done < <(
    find "${roots[@]}" -type f \
      \( -name '*.deb' -o -name '*.rpm' -o -name '*.pkg.tar.*' \) \
      ! -name '*.sig' 2>/dev/null | sort
  )

  if [[ ! -s "$TMP_LIST" ]]; then
    log "nothing to prune"
    return 0
  fi

  if [[ "$all" -eq 1 ]]; then
    mapfile -t names < <(cut -f2 "$TMP_LIST" | sort -u)
  fi

  local removed=0
  local pkg keep_versions
  for pkg in "${names[@]}"; do
    keep_versions="$(awk -F'\t' -v n="$pkg" '$2 == n {print $3}' "$TMP_LIST" \
      | sort -V | uniq | tail -n "$keep")"
    [[ -n "$keep_versions" ]] || continue

    while IFS=$'\t' read -r f name ver; do
      [[ "$name" == "$pkg" ]] || continue
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
  done

  if [[ "$removed" -eq 0 ]]; then
    log "nothing to prune"
  elif [[ "$yes" -eq 1 ]]; then
    log "removed $removed file(s). Run ./scripts/publish.sh --sync if needed."
  else
    log "dry run: $removed file(s) would be removed. Re-run with --yes."
  fi
}

main "$@"
