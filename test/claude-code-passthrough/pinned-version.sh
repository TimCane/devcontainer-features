#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Scenario: pinned-version — feature with an explicit version option.

set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "claude is on PATH"            bash -c "command -v claude"
check "claude --version runs"        bash -c "claude --version"
check "link helper is staged"        test -x /usr/local/share/claude-code-passthrough/link-credentials.sh
check "options.env is staged"        test -e /usr/local/share/claude-code-passthrough/options.env

reportResults
