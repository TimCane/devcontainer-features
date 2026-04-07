#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# claude-code-passthrough feature installer.
#
# Installs the Claude Code CLI from npm and stages a postCreate helper that
# symlinks the bind-mounted host credentials file into the remote user's
# $HOME/.claude/ at container start time.
#
# Runs as root at image build time. The bind mount is NOT live yet at this
# point — we cannot touch /usr/local/share/claude-code/.credentials.json here.

set -euo pipefail

VERSION="${VERSION:-latest}"
PASSTHROUGHHOSTAUTH="${PASSTHROUGHHOSTAUTH:-true}"

REMOTE_USER="${_REMOTE_USER:-root}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/root}"

echo "[claude-code-passthrough] installing @anthropic-ai/claude-code@${VERSION}"

if ! command -v npm >/dev/null 2>&1; then
	echo "[claude-code-passthrough] ERROR: npm not found on PATH." >&2
	echo "[claude-code-passthrough] This feature dependsOn ghcr.io/devcontainers/features/node — node should have been installed first." >&2
	exit 1
fi

npm install -g "@anthropic-ai/claude-code@${VERSION}"

# Stage the postCreate helper next to the mount target so it ships with the
# image. The mount target file itself doesn't exist until run time; the
# staging directory does.
STAGING_DIR="/usr/local/share/claude-code-passthrough"
install -d -m 0755 "${STAGING_DIR}"

# Ship the helper script verbatim from the feature directory (keeps it in its
# own file so editors syntax-highlight it properly).
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -m 0755 "${SELF_DIR}/scripts/link-credentials.sh" "${STAGING_DIR}/link-credentials.sh"

# Bake option values into an env file the helper sources at run time.
# postCreateCommand does not run as a login shell, so /etc/profile.d/* is
# not sourced — this env file is how feature options cross that boundary.
cat >"${STAGING_DIR}/options.env" <<EOF
PASSTHROUGH_HOST_AUTH="${PASSTHROUGHHOSTAUTH}"
EOF
chmod 0644 "${STAGING_DIR}/options.env"

# Ensure the remote user owns its (future) ~/.claude directory's parent;
# the directory itself is created at run time by the helper.
if [ "${REMOTE_USER}" != "root" ] && id "${REMOTE_USER}" >/dev/null 2>&1; then
	install -d -m 0755 -o "${REMOTE_USER}" -g "${REMOTE_USER}" "${REMOTE_USER_HOME}/.claude" || true
fi

echo "[claude-code-passthrough] install complete."
