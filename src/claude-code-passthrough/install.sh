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
MOUNTCREDENTIALS="${MOUNTCREDENTIALS:-true}"

REMOTE_USER="${_REMOTE_USER:-root}"
REMOTE_USER_HOME="${_REMOTE_USER_HOME:-/root}"

echo "[claude-code-passthrough] installing @anthropic-ai/claude-code@${VERSION}"

if ! command -v npm >/dev/null 2>&1; then
	echo "[claude-code-passthrough] ERROR: npm not found on PATH." >&2
	echo "[claude-code-passthrough] This feature dependsOn ghcr.io/devcontainers/features/node — node should have been installed first." >&2
	exit 1
fi

npm install -g "@anthropic-ai/claude-code@${VERSION}"

# Stage the postCreate symlink helper next to the mount target so it ships
# with the image. The mount target file itself doesn't exist until run time;
# the staging directory does.
install -d -m 0755 /usr/local/share/claude-code-passthrough

cat >/usr/local/share/claude-code-passthrough/link-credentials.sh <<'EOS'
#!/usr/bin/env bash
#
# postCreateCommand helper for the claude-code-passthrough feature.
# Runs as the remote user at container start, AFTER the bind mount is live.

set -euo pipefail

STAGING="/usr/local/share/claude-code-passthrough/.credentials.json"
TARGET_DIR="${HOME}/.claude"
TARGET="${TARGET_DIR}/.credentials.json"

if [ "${MOUNT_CREDENTIALS:-true}" != "true" ]; then
	echo "[claude-code-passthrough] mountCredentials=false — skipping credential symlink."
	exit 0
fi

if [ -d "${STAGING}" ]; then
	cat >&2 <<'MSG'
[claude-code-passthrough] ERROR: the host credentials path is a DIRECTORY, not a file.

This happens when ~/.claude/.credentials.json did not exist on the host at the
time the dev container was first built. Docker silently created an empty
directory at the bind-mount source instead of binding a file.

To fix:
  1. On the host, run:    mkdir -p ~/.claude && touch ~/.claude/.credentials.json
     (or authenticate Claude Code on the host first, which creates the file)
  2. Rebuild the dev container (Dev Containers: Rebuild Container).
MSG
	exit 1
fi

if [ ! -e "${STAGING}" ]; then
	echo "[claude-code-passthrough] WARNING: ${STAGING} does not exist; bind mount missing. Skipping symlink." >&2
	exit 0
fi

mkdir -p "${TARGET_DIR}"

# Replace any pre-existing file/symlink at the target.
if [ -e "${TARGET}" ] || [ -L "${TARGET}" ]; then
	rm -f "${TARGET}"
fi

ln -s "${STAGING}" "${TARGET}"
echo "[claude-code-passthrough] linked ${TARGET} -> ${STAGING}"
EOS

chmod 0755 /usr/local/share/claude-code-passthrough/link-credentials.sh

# Bake the option into the helper's environment so postCreateCommand picks it
# up regardless of how the dev container is launched.
cat >/etc/profile.d/claude-code-passthrough.sh <<EOF
export MOUNT_CREDENTIALS="${MOUNTCREDENTIALS}"
EOF
chmod 0644 /etc/profile.d/claude-code-passthrough.sh

# Ensure the remote user owns its (future) ~/.claude directory's parent;
# the directory itself is created at run time by the helper.
if [ "${REMOTE_USER}" != "root" ] && id "${REMOTE_USER}" >/dev/null 2>&1; then
	install -d -m 0755 -o "${REMOTE_USER}" -g "${REMOTE_USER}" "${REMOTE_USER_HOME}/.claude" || true
fi

echo "[claude-code-passthrough] install complete."
