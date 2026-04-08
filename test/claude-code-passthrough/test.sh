#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Smoke test for the claude-code-passthrough feature.

set -euo pipefail

# Optional: import test helpers from the dev container CLI test runner.
# shellcheck source=/dev/null
source dev-container-features-test-lib

check "claude is on PATH"            bash -c "command -v claude"
check "claude --version runs"        bash -c "claude --version"
check "link helper is staged"        test -x /usr/local/share/claude-code-passthrough/link-credentials.sh
check "options.env is staged"        test -e /usr/local/share/claude-code-passthrough/options.env
check "credentials staging exists"   test -e /usr/local/share/claude-code-passthrough/.credentials.json
check "account state staging exists" test -e /usr/local/share/claude-code-passthrough/.claude.json

reportResults
