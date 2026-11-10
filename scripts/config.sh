#!/usr/bin/env bash
# shellcheck shell=bash
#
# Central configuration for the TTP pkgs repository.
# Edit BASE_URL / REPO_NAME here if they ever change.

REPO_NAME="${REPO_NAME:-ttp-pkgs}"
REPO_TITLE="${REPO_TITLE:-TTP pkgs}"
ORIGIN="${ORIGIN:-TTP-pkgs}"
BASE_URL="${BASE_URL:-https://pkgs.tactalapaca.com}"

# How many versions of each package to keep in the published repo.
KEEP_VERSIONS="${KEEP_VERSIONS:-2}"

# APT layout
APT_SUITE="${APT_SUITE:-stable}"
APT_COMPONENT="${APT_COMPONENT:-main}"

# rclone remote + bucket (configured by scripts/init-r2.sh)
R2_REMOTE="${R2_REMOTE:-$REPO_NAME}"
R2_BUCKET="${R2_BUCKET:-$REPO_NAME}"

# Paths (derived from this file's location, so scripts work from any cwd)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PACKAGES_DIR="$ROOT_DIR/packages"
REPO_DIR="$ROOT_DIR/repo"
KEYS_DIR="$ROOT_DIR/keys"
SETUP_DIR="$ROOT_DIR/setup"

# Published as $BASE_URL/keys/<repo>.asc
KEY_FILE="$KEYS_DIR/$REPO_NAME.asc"
