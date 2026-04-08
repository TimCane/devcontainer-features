#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Installs Claude Code from npm and stages a postCreate helper that wires
# up the host credential bind mounts at container start. Runs as root at
# image build time, before the bind mounts are live.

set -euo pipefail

CLAUDE_VERSION="${CLAUDEVERSION:-latest}"
PASSTHROUGHHOSTAUTH="${PASSTHROUGHHOSTAUTH:-true}"
REMOTE_USER="${_REMOTE_USER:-root}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/root}"

STAGING_DIR="/usr/local/share/claude-code-passthrough"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[claude-code-passthrough] $*"; }
err() { echo "[claude-code-passthrough] $*" >&2; }

remote_user_exists() {
	[ "${REMOTE_USER}" != "root" ] && id "${REMOTE_USER}" >/dev/null 2>&1
}

require_npm() {
	if ! command -v npm >/dev/null 2>&1; then
		err "ERROR: npm not found on PATH."
		err "This feature dependsOn ghcr.io/devcontainers/features/node — node should have been installed first."
		exit 1
	fi
}

validate_version() {
	# Accept "latest", a semver-ish version (1.2.3, 1.2.3-beta.1, with optional
	# leading 'v'), or a dist-tag (alphanumerics, dots, dashes, underscores).
	# Reject anything that could smuggle shell metacharacters into the npm
	# install argument.
	case "${CLAUDE_VERSION}" in
		latest) return 0 ;;
	esac
	if ! [[ "${CLAUDE_VERSION}" =~ ^[A-Za-z0-9._-]+$ ]]; then
		err "ERROR: invalid claudeVersion '${CLAUDE_VERSION}'."
		err "Expected 'latest', a semver (e.g. 1.2.3), or a dist-tag matching [A-Za-z0-9._-]+."
		exit 1
	fi
}

install_claude_code() {
	log "installing @anthropic-ai/claude-code@${CLAUDE_VERSION}"
	npm install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}"
}

# Shim ~/.local/bin/claude → npm binary. Claude's npm build auto-migrates
# to the native installer in the background; per anthropics/claude-code#26173
# the migration sets installMethod="native" but fails to create the launcher,
# leaving warnings on every start. Pointing the expected path at the npm
# binary silences the self-check without disabling auto-updates — a future
# successful migration will overwrite this symlink with a real binary.
shim_local_bin_launcher() {
	local npm_claude
	npm_claude="$(command -v claude || true)"
	if [ -z "${npm_claude}" ]; then
		return
	fi

	local local_bin="${REMOTE_USER_HOME}/.local/bin"

	if remote_user_exists; then
		install -d -m 0755 -o "${REMOTE_USER}" -g "${REMOTE_USER}" "${REMOTE_USER_HOME}/.local"
		install -d -m 0755 -o "${REMOTE_USER}" -g "${REMOTE_USER}" "${local_bin}"
		ln -sfn "${npm_claude}" "${local_bin}/claude"
		chown -h "${REMOTE_USER}:${REMOTE_USER}" "${local_bin}/claude" || true
	else
		install -d -m 0755 "${local_bin}"
		ln -sfn "${npm_claude}" "${local_bin}/claude"
	fi

	log "linked ${local_bin}/claude -> ${npm_claude}"
}

# Stage the postCreate helper next to the bind-mount targets. The target
# files don't exist until run time, but the staging dir does.
stage_helper_script() {
	install -d -m 0755 "${STAGING_DIR}"
	install -m 0755 "${SELF_DIR}/scripts/link-credentials.sh" "${STAGING_DIR}/link-credentials.sh"
}

# Bake option values into an env file. postCreateCommand isn't a login shell,
# so /etc/profile.d/* won't fire — this is how options cross that boundary.
write_options_env() {
	cat >"${STAGING_DIR}/options.env" <<EOF
PASSTHROUGH_HOST_AUTH="${PASSTHROUGHHOSTAUTH}"
EOF
	chmod 0644 "${STAGING_DIR}/options.env"
}

# Pre-create ~/.claude so the helper doesn't have to mkdir as the remote user.
prepare_claude_home() {
	if remote_user_exists; then
		install -d -m 0755 -o "${REMOTE_USER}" -g "${REMOTE_USER}" "${REMOTE_USER_HOME}/.claude" || true
	fi
}

main() {
	validate_version
	require_npm
	install_claude_code
	shim_local_bin_launcher
	stage_helper_script
	write_options_env
	prepare_claude_home
	log "install complete."
}

main "$@"
