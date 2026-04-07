#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# postCreateCommand helper for the claude-code-passthrough feature.
# Runs as the remote user at container start, AFTER the bind mounts are live.
#
# Two host files are passed through together (both or neither — enabling
# only one leaves Claude Code in a broken state):
#
#   1. ~/.claude/.credentials.json — OAuth tokens. SYMLINKED so token refresh
#      writes straight back to the host.
#
#   2. ~/.claude.json              — Account state, onboarding flags, project
#      list, tip history, etc. COPIED on first start only (target must not
#      exist). Live-linking would let the container pollute the host file
#      with container-specific paths every time `claude` runs.
#
# Without (2), `claude` re-runs login/onboarding even when (1) is valid,
# because it has no record that the user is authenticated. Without (1),
# (2) points at an unauthenticated account. Hence one switch for both.
#
# Option values are read from options.env alongside this script, written by
# install.sh at image build time. postCreateCommand does not run as a login
# shell, so /etc/profile.d/* is not sourced — the env file is how we get
# feature option values across that boundary.

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "${SELF_DIR}/options.env"

CREDS_STAGING="${SELF_DIR}/.credentials.json"
CREDS_TARGET_DIR="${HOME}/.claude"
CREDS_TARGET="${CREDS_TARGET_DIR}/.credentials.json"

ACCOUNT_STAGING="${SELF_DIR}/.claude.json"
ACCOUNT_TARGET="${HOME}/.claude.json"

bind_mount_is_directory_error() {
	# $1 = host-side filename hint, $2 = staging path
	local host_file="$1"
	local staging="$2"
	cat >&2 <<MSG
[claude-code-passthrough] ERROR: ${staging} is a DIRECTORY, not a file.

This happens when ${host_file} did not exist on the host at the time the dev
container was first built. Docker silently created an empty directory at the
bind-mount source instead of binding a file.

To fix:
  1. On the host, ensure ${host_file} exists as a file
     (authenticate Claude Code on the host first, which creates it).
  2. Rebuild the dev container (Dev Containers: Rebuild Container).
MSG
}

if [ "${PASSTHROUGH_HOST_AUTH:-true}" != "true" ]; then
	echo "[claude-code-passthrough] passthroughHostAuth=false — skipping credential symlink and account seed."
	exit 0
fi

# ---------------------------------------------------------------------------
# 1. Credentials — symlink
# ---------------------------------------------------------------------------
if [ -d "${CREDS_STAGING}" ]; then
	bind_mount_is_directory_error "~/.claude/.credentials.json" "${CREDS_STAGING}"
	exit 1
fi

if [ ! -e "${CREDS_STAGING}" ]; then
	echo "[claude-code-passthrough] WARNING: ${CREDS_STAGING} does not exist; bind mount missing. Skipping symlink." >&2
else
	mkdir -p "${CREDS_TARGET_DIR}"
	if [ -e "${CREDS_TARGET}" ] || [ -L "${CREDS_TARGET}" ]; then
		rm -f "${CREDS_TARGET}"
	fi
	ln -s "${CREDS_STAGING}" "${CREDS_TARGET}"
	echo "[claude-code-passthrough] linked ${CREDS_TARGET} -> ${CREDS_STAGING}"
fi

# ---------------------------------------------------------------------------
# 2. Account state — copy on first start
# ---------------------------------------------------------------------------
if [ -d "${ACCOUNT_STAGING}" ]; then
	bind_mount_is_directory_error "~/.claude.json" "${ACCOUNT_STAGING}"
	exit 1
fi

if [ ! -e "${ACCOUNT_STAGING}" ]; then
	echo "[claude-code-passthrough] WARNING: ${ACCOUNT_STAGING} does not exist; bind mount missing. Skipping account seed." >&2
	exit 0
fi

if [ -e "${ACCOUNT_TARGET}" ]; then
	echo "[claude-code-passthrough] ${ACCOUNT_TARGET} already exists — leaving container-local copy untouched."
	exit 0
fi

# Copy, not symlink: container will mutate this file constantly and we don't
# want those writes to bleed back to the host.
cp "${ACCOUNT_STAGING}" "${ACCOUNT_TARGET}"
chmod 0600 "${ACCOUNT_TARGET}"
echo "[claude-code-passthrough] seeded ${ACCOUNT_TARGET} from host (copy)"
