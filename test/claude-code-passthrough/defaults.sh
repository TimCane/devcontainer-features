#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Scenario: defaults — feature with no options set.

set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "claude is on PATH"            bash -c "command -v claude"
check "claude --version runs"        bash -c "claude --version"
check "link helper is staged"        test -x /opt/claude-code-passthrough/link-credentials.sh
check "options.env is staged"        test -e /opt/claude-code-passthrough/options.env
check "credentials staging exists"   test -e /opt/claude-code-passthrough/.credentials.json
check "account state staging exists" test -e /opt/claude-code-passthrough/.claude.json

# postCreateCommand should have run link-credentials.sh, leaving
# ~/.claude/.credentials.json as a symlink to the staging path. The
# symlink — not a copy — is what makes Claude's token refreshes flow
# back to the host through the bind mount.
check "credentials path is a symlink" test -L "${HOME}/.claude/.credentials.json"
check "credentials symlink targets staging" \
	bash -c '[ "$(readlink "${HOME}/.claude/.credentials.json")" = "/opt/claude-code-passthrough/.credentials.json" ]'

# Write through the symlink and confirm the bind-mount target sees the
# update — this is the in-container half of the bidirectional sync
# guarantee. (The host half is a Docker bind-mount property, not
# something we can assert from inside the container.)
check "writes through symlink reach the bind-mount target" bash -c '
	set -e
	marker="passthrough-sync-$$-$(date +%s)"
	original="$(cat /opt/claude-code-passthrough/.credentials.json)"
	trap '"'"'printf "%s" "${original}" > /opt/claude-code-passthrough/.credentials.json'"'"' EXIT
	printf "%s" "${marker}" > "${HOME}/.claude/.credentials.json"
	[ "$(cat /opt/claude-code-passthrough/.credentials.json)" = "${marker}" ]
'

# Account state is COPIED (not linked) because Claude rewrites it with
# container-local paths and live-linking would corrupt the host file.
check "account state is a regular file, not a symlink" \
	bash -c '[ -f "${HOME}/.claude.json" ] && [ ! -L "${HOME}/.claude.json" ]'

reportResults
