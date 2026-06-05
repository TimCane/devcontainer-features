#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Scenario: with-global-config — passthroughHostConfig=true. The host's
# ~/.claude is bind-mounted to the staging dir and the helper copies a
# curated config subset into the container's ~/.claude at postCreate.
# The CI seed step plants CLAUDE.md, settings.json and commands/ on the
# host so the copy has something to pull through.

set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "claude is on PATH"                  bash -c "command -v claude"
check "link helper is staged"              test -x /opt/claude-code-passthrough/link-credentials.sh
check "options.env records config opt-in"  grep -q 'PASSTHROUGH_HOST_CONFIG="true"' /opt/claude-code-passthrough/options.env
check "host config staging mounted"        test -d /opt/claude-code-passthrough/host-claude-config

# postCreateCommand should have copied the curated subset into ~/.claude.
check "CLAUDE.md copied into ~/.claude"    test -f "${HOME}/.claude/CLAUDE.md"
check "settings.json copied into ~/.claude" test -f "${HOME}/.claude/settings.json"
check "commands/ copied into ~/.claude"    test -d "${HOME}/.claude/commands"

# Copied, not linked — container edits must not write back to the host.
check "copied config is a regular file, not a symlink" \
	bash -c '! test -L "${HOME}/.claude/CLAUDE.md"'

reportResults
