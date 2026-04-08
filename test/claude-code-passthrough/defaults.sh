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

reportResults
