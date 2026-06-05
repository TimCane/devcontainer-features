#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# postCreateCommand helper for claude-code-passthrough. Runs as the remote
# user once the bind mounts are live. Wires two host files into the
# container — both or neither, since either alone leaves Claude broken:
#   1. ~/.claude/.credentials.json — OAuth tokens. SYMLINKED so refreshes
#      write back to the host.
#   2. ~/.claude.json — account/onboarding state. COPIED on first start
#      only, because Claude rewrites it constantly with container-local
#      paths and live-linking would pollute the host.
# Options come from options.env (postCreate isn't a login shell, so
# /etc/profile.d/* doesn't fire).

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
. "${SELF_DIR}/options.env"

CREDS_STAGING="${SELF_DIR}/.credentials.json"
CREDS_TARGET_DIR="${HOME}/.claude"
CREDS_TARGET="${CREDS_TARGET_DIR}/.credentials.json"

ACCOUNT_STAGING="${SELF_DIR}/.claude.json"
ACCOUNT_TARGET="${HOME}/.claude.json"

# Bind mount of the host's whole ~/.claude. Only a curated subset is copied
# out of it (see seed_global_config) — never the runtime state or the
# separately-handled credential files.
CONFIG_STAGING="${SELF_DIR}/host-claude-config"
CONFIG_ITEMS=(CLAUDE.md settings.json keybindings.json commands skills agents)

log()  { echo "[claude-code-passthrough] $*"; }
warn() { echo "[claude-code-passthrough] WARNING: $*" >&2; }

# Emitted when a bind-mount staging path resolves to a directory instead of
# a file — Docker silently mkdirs the source if the host file is missing at
# build time. The fix is on the host, so the message walks the user through it.
bind_mount_is_directory_error() {
	local host_file="$1" staging="$2"
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

link_credentials() {
	if [ -d "${CREDS_STAGING}" ]; then
		# shellcheck disable=SC2088 # literal "~" shown to user in error message
		bind_mount_is_directory_error "~/.claude/.credentials.json" "${CREDS_STAGING}"
		exit 1
	fi

	if [ ! -e "${CREDS_STAGING}" ]; then
		warn "${CREDS_STAGING} does not exist; bind mount missing. Skipping symlink."
		return
	fi

	mkdir -p "${CREDS_TARGET_DIR}"
	if [ -e "${CREDS_TARGET}" ] || [ -L "${CREDS_TARGET}" ]; then
		rm -f "${CREDS_TARGET}"
	fi
	ln -s "${CREDS_STAGING}" "${CREDS_TARGET}"
	log "linked ${CREDS_TARGET} -> ${CREDS_STAGING}"
}

seed_account_state() {
	if [ -d "${ACCOUNT_STAGING}" ]; then
		# shellcheck disable=SC2088 # literal "~" shown to user in error message
		bind_mount_is_directory_error "~/.claude.json" "${ACCOUNT_STAGING}"
		exit 1
	fi

	if [ ! -e "${ACCOUNT_STAGING}" ]; then
		warn "${ACCOUNT_STAGING} does not exist; bind mount missing. Skipping account seed."
		return
	fi

	if [ -e "${ACCOUNT_TARGET}" ]; then
		log "${ACCOUNT_TARGET} already exists — leaving container-local copy untouched."
		return
	fi

	cp "${ACCOUNT_STAGING}" "${ACCOUNT_TARGET}"
	chmod 0600 "${ACCOUNT_TARGET}"
	log "seeded ${ACCOUNT_TARGET} from host (copy)"
}

# Copy the curated config subset from the host bind mount into the container's
# ~/.claude. COPIED, not linked, so container edits stay container-local and
# never mutate the host's real global config. Each rebuild re-seeds from the
# host. The credentials symlink (~/.claude/.credentials.json) is left untouched
# because .credentials.json is not in CONFIG_ITEMS.
seed_global_config() {
	if [ ! -d "${CONFIG_STAGING}" ]; then
		warn "${CONFIG_STAGING} does not exist; bind mount missing. Skipping global config passthrough."
		return
	fi

	mkdir -p "${HOME}/.claude"

	local copied=0 item src
	for item in "${CONFIG_ITEMS[@]}"; do
		src="${CONFIG_STAGING}/${item}"
		[ -e "${src}" ] || continue
		rm -rf "${HOME:?}/.claude/${item}"
		cp -R "${src}" "${HOME}/.claude/${item}"
		copied=$((copied + 1))
	done

	if [ "${copied}" -eq 0 ]; then
		log "no host global config items found under ${CONFIG_STAGING}; nothing copied."
	else
		log "copied ${copied} host global config item(s) into ${HOME}/.claude."
	fi
}

main() {
	if [ "${PASSTHROUGH_HOST_AUTH:-true}" = "true" ]; then
		link_credentials
		seed_account_state
	else
		log "passthroughHostAuth=false — skipping credential symlink and account seed."
	fi

	if [ "${PASSTHROUGH_HOST_CONFIG:-false}" = "true" ]; then
		seed_global_config
	fi
}

main "$@"
