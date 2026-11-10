#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

README="$ROOT_DIR/README.md"
[[ -f "$README" ]] || die "README.md not found at $README"

TMP_PKGS=""
TMP_KEY=""
cleanup() {
  [[ -n "$TMP_PKGS" ]] && rm -f "$TMP_PKGS"
  [[ -n "$TMP_KEY" ]] && rm -f "$TMP_KEY"
  return 0
}
trap cleanup EXIT

# Drop packaging revisions for display: 0.1.3-1 -> 0.1.3
_strip_rev() {
  printf '%s\n' "${1%-[0-9]*}"
}

_arch_version() {
  local f=$1 v
  v="$(pacman -Qip "$f" 2>/dev/null \
    | awk -F': ' '/^Version[[:space:]]*:/{print $2; exit}')"
  _strip_rev "$v"
}

_render_packages() {
  declare -A versions=()
  declare -A fmt=()
  local f name v

  shopt -s nullglob
  for f in "$REPO_DIR"/apt/pool/"$APT_COMPONENT"/*/*/*.deb; do
    name="$(dpkg-deb -f "$f" Package 2>/dev/null || true)"
    v="$(_strip_rev "$(dpkg-deb -f "$f" Version 2>/dev/null || true)")"
    [[ -n "$name" && -n "$v" ]] || continue
    versions["$name"]+="$v "
    fmt["$name"]+="deb "
  done

  for f in "$REPO_DIR"/rpm/*/*.rpm; do
    name="$(rpm -qp --qf '%{NAME}' "$f" 2>/dev/null || true)"
    v="$(rpm -qp --qf '%{VERSION}' "$f" 2>/dev/null || true)"
    [[ -n "$name" && -n "$v" ]] || continue
    versions["$name"]+="$v "
    fmt["$name"]+="rpm "
  done

  for f in "$REPO_DIR"/arch/*/*.pkg.tar.*; do
    [[ "$f" == *.sig ]] && continue
    name="$(pacman -Qip "$f" 2>/dev/null \
      | awk -F': ' '/^Name[[:space:]]*:/{print $2; exit}')"
    v="$(_arch_version "$f")"
    [[ -n "$name" && -n "$v" ]] || continue
    versions["$name"]+="$v "
    fmt["$name"]+="arch "
  done
  shopt -u nullglob

  printf '| Package | Latest | Available versions | Formats |\n'
  printf '| --- | --- | --- | --- |\n'

  if [[ ${#versions[@]} -eq 0 ]]; then
    printf '| _none yet_ | — | — | — |\n'
    return 0
  fi

  local pkg vers latest available formats
  for pkg in $(printf '%s\n' "${!versions[@]}" | sort); do
    vers="$(printf '%s\n' ${versions[$pkg]} | awk '
      NF && !seen[$0]++
    ' | sort -Vr)"
    latest="$(printf '%s\n' "$vers" | head -n1)"
    available="$(printf '%s\n' "$vers" | awk '
      { out = out (out ? ", " : "") "`" $0 "`" }
      END { print out }
    ')"

    formats="$(printf '%s\n' ${fmt[$pkg]} | awk '
      NF && !seen[$0]++ { out = out (out ? ", " : "") $0 }
      END { print out }
    ')"
    printf '| `%s` | **`%s`** | %s | %s |\n' "$pkg" "$latest" "$available" "$formats"
  done
}

main() {
  auto_key
  TMP_PKGS="$(mktemp)"
  TMP_KEY="$(mktemp)"

  _render_packages > "$TMP_PKGS"

  {
    if [[ -n "${KEY_ID:-}" ]]; then
      printf 'Signing key fingerprint: `%s`\n\n' "$KEY_ID"
    else
      printf 'Signing key fingerprint: _(not configured yet)_\n\n'
    fi
    printf '```bash\n'
    printf 'curl -fsSL %s/keys/%s.asc | gpg --show-keys --with-fingerprint\n' \
      "$BASE_URL" "$REPO_NAME"
    printf '```\n'
  } > "$TMP_KEY"

  update_block "$README" '<!-- PACKAGES:START -->' '<!-- PACKAGES:END -->' "$TMP_PKGS"
  update_block "$README" '<!-- KEY:START -->' '<!-- KEY:END -->' "$TMP_KEY"

  info "README.md package table updated"
}

main "$@"
