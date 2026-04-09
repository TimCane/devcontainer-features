#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Scenario: no-passthrough — passthroughHostAuth=false. The bind mounts
# are still declared (features cannot opt out of their own mounts), but
# the helper should skip the symlink and account state copy.

set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "claude is on PATH"               bash -c "command -v claude"
check "link helper is staged"           test -x /opt/claude-code-passthrough/link-credentials.sh
check "options.env records opt-out"     grep -q 'PASSTHROUGH_HOST_AUTH="false"' /opt/claude-code-passthrough/options.env
check "credentials symlink NOT created" bash -c '! test -L "${HOME}/.claude/.credentials.json"'

reportResults
