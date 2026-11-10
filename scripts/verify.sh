#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

OK=0
FAIL=0

pass() { info "ok   $*"; OK=$((OK + 1)); }
fail() { warn "FAIL $*"; FAIL=$((FAIL + 1)); }

check_gpg() {
  local label=$1 sig=$2 data=${3:-}
  if [[ ! -f "$sig" ]]; then fail "$label (missing signature)"; return; fi
  if [[ -n "$data" ]]; then
    if gpg --verify "$sig" "$data" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
  else
    if gpg --verify "$sig" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
  fi
}

main() {
  local unsigned="${UNSIGNED:-0}"

  if [[ "$unsigned" -eq 0 && -z "${KEY_ID:-}" && -f "$KEY_FILE" ]]; then
    KEY_ID="$(detect_key_id || true)"
    export KEY_ID
  fi
  if [[ -z "${KEY_ID:-}" ]]; then
    unsigned=1
  fi
  if [[ "$unsigned" -eq 1 ]]; then
    warn "no signing key / UNSIGNED=1: skipping signature checks"
  fi

  # --- APT -----------------------------------------------------------------
  local inrelease="$REPO_DIR/apt/dists/$APT_SUITE/InRelease"
  local packages
  packages="$(find "$REPO_DIR/apt" -name Packages -type f | head -n1 || true)"
  if [[ -n "$packages" ]]; then
    pass "APT Packages present ($(grep -c '^Package:' "$packages") package(s))"
    if [[ "$unsigned" -eq 0 ]]; then check_gpg "APT InRelease signature" "$inrelease"; fi
  else
    fail "APT Packages missing"
  fi

  # --- RPM -----------------------------------------------------------------
  local dir repomd
  shopt -s nullglob
  for dir in "$REPO_DIR"/rpm/*/; do
    [[ -d "$dir/repodata" ]] || continue
    repomd="$dir/repodata/repomd.xml"
    if [[ -f "$repomd" ]]; then
      pass "RPM repodata $(basename "$dir")"
      if [[ "$unsigned" -eq 0 ]]; then
        check_gpg "RPM repomd.xml signature ($(basename "$dir"))" \
          "$dir/repodata/repomd.xml.asc" "$repomd"
      fi
    else
      fail "RPM repomd.xml missing in ${dir#"$ROOT_DIR"/}"
    fi
  done

  if [[ "$unsigned" -eq 0 && -f "$KEY_FILE" ]]; then
    local tmpdb
    tmpdb="$(mktemp -d)"
    rpm --dbpath="$tmpdb" --initdb >/dev/null 2>&1 || true
    rpm --dbpath="$tmpdb" --import "$KEY_FILE" >/dev/null 2>&1 || true

    local rpm
    for rpm in "$REPO_DIR"/rpm/*/*.rpm; do
      if rpmkeys --dbpath="$tmpdb" --checksig "$rpm" 2>/dev/null | grep -q 'signatures OK'; then
        pass "RPM package signature $(basename "$rpm")"
      else
        fail "RPM package signature $(basename "$rpm")"
      fi
    done
    rm -rf "$tmpdb"
  fi

  # --- Arch ----------------------------------------------------------------
  local db count
  for db in "$REPO_DIR"/arch/*/"$REPO_NAME".db; do
    [[ -f "$db" ]] || continue
    if [[ -L "$db" ]]; then
      fail "Arch database is a symlink: ${db#"$ROOT_DIR"/} (must be a real file for R2)"
      continue
    fi
    count="$(tar -tf "$db" 2>/dev/null | grep -c '/desc$' || true)"
    pass "Arch database $(basename "$(dirname "$db")") ($count package(s))"
    if [[ "$unsigned" -eq 0 ]]; then
      check_gpg "Arch database signature ($(basename "$(dirname "$db")"))" \
        "${db%.db}.db.sig" "$db"
    fi
  done
  shopt -u nullglob

  # --- setup scripts -------------------------------------------------------
  [[ -x "$REPO_DIR/setup/install.sh" ]] \
    && pass "setup/install.sh present" \
    || fail "setup/install.sh missing"
  [[ -f "$REPO_DIR/rpm/$REPO_NAME.repo" ]] \
    && pass "RPM .repo file present" \
    || fail "RPM .repo file missing"

  echo
  if [[ "$FAIL" -gt 0 ]]; then
    die "$FAIL check(s) failed, $OK passed"
  fi
  log "all checks passed ($OK)"
}

main "$@"
