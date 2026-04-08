#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Static check: every bind mount source in devcontainer-feature.json that
# references ${localEnv:HOME} must also reference ${localEnv:USERPROFILE} in
# the same string. On Windows hosts HOME is unset and USERPROFILE holds the
# user's home directory, so the two must be concatenated for cross-platform
# expansion. Dropping USERPROFILE causes a silent expansion to an empty
# string and a bind-mount failure with a literal "/.claude/..." path.

set -euo pipefail

FEATURE_JSON="$(dirname "$0")/../../src/claude-code-passthrough/devcontainer-feature.json"

if [ ! -f "$FEATURE_JSON" ]; then
	echo "lint-mounts: cannot find $FEATURE_JSON" >&2
	exit 1
fi

# Extract every mount "source" line, then flag any that mention HOME without USERPROFILE.
bad=$(grep -E '"source"[[:space:]]*:' "$FEATURE_JSON" \
	| grep -F '${localEnv:HOME}' \
	| grep -vF '${localEnv:USERPROFILE}' \
	|| true)

if [ -n "$bad" ]; then
	echo "lint-mounts: mount source uses \${localEnv:HOME} without \${localEnv:USERPROFILE}:" >&2
	echo "$bad" >&2
	echo "Fix: use \"\${localEnv:HOME}\${localEnv:USERPROFILE}/...\" so Windows hosts (where HOME is unset) resolve correctly." >&2
	exit 1
fi

echo "lint-mounts: OK"
