#!/usr/bin/env bash
# shellcheck shell=bash
#
# Shared helpers. Sourced after config.sh.

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

# Print the fingerprint of the public key in keys/<repo>.asc.
detect_key_id() {
  if [[ -n "${KEY_ID:-}" ]]; then
    printf '%s\n' "$KEY_ID"
    return 0
  fi
  [[ -f "$KEY_FILE" ]] || return 1
  gpg --with-colons --show-keys "$KEY_FILE" 2>/dev/null \
    | awk -F: '/^fpr:/{print $10; exit}'
}

# Best-effort key detection for scripts run outside publish.sh.
auto_key() {
  if [[ "${UNSIGNED:-0}" -eq 1 ]]; then
    KEY_ID=""
    export KEY_ID
    return 0
  fi
  if [[ -z "${KEY_ID:-}" && -f "$KEY_FILE" ]]; then
    KEY_ID="$(detect_key_id || true)"
    export KEY_ID
  fi
  if [[ -z "${KEY_ID:-}" ]]; then
    warn "no signing key found; building unsigned metadata"
  fi
}

# Populate KEY_ID unless UNSIGNED=1 was requested.
resolve_key() {
  if [[ "${UNSIGNED:-0}" -eq 1 ]]; then
    KEY_ID=""
    export KEY_ID
    return 0
  fi

  KEY_ID="$(detect_key_id || true)"
  if [[ -z "$KEY_ID" ]]; then
    die "no signing key found at $KEY_FILE. Run scripts/init-key.sh first, or use --unsigned for a local test."
  fi
  export KEY_ID
}

ensure_repo_dirs() {
  mkdir -p \
    "$PACKAGES_DIR" \
    "$REPO_DIR/apt/pool/$APT_COMPONENT" \
    "$REPO_DIR/rpm" \
    "$REPO_DIR/arch" \
    "$REPO_DIR/keys" \
    "$REPO_DIR/setup"
}

# Replace the contents of a marker block inside a file.
#   update_block FILE START_MARKER END_MARKER CONTENT_FILE
update_block() {
  local file=$1 start=$2 end=$3 content=$4 tmp mode
  # mktemp creates 0600 files; keep the original mode when replacing it.
  mode="$(stat -c '%a' "$file" 2>/dev/null || echo 644)"
  tmp="$(mktemp)"
  awk -v start="$start" -v end="$end" -v content="$content" '
    index($0, start) {
      print
      while ((getline line < content) > 0) print line
      close(content)
      skip = 1
      next
    }
    index($0, end) { skip = 0 }
    !skip { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  chmod "$mode" "$file"
}
