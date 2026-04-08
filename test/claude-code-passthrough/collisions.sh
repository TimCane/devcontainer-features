#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Scenario: collisions — exercises link-credentials.sh against pre-existing
# state in ${HOME}, plus a permission-error case:
#   1. ~/.claude/.credentials.json already exists as a regular file. Helper
#      should replace it with the symlink (Claude won't refresh through a
#      stale local copy).
#   2. ~/.claude/.credentials.json already exists as a stale symlink to
#      somewhere else. Helper should replace it with the new symlink.
#   3. ~/.claude.json already exists. Helper should LEAVE IT ALONE — it's
#      the container-local copy that's been mutated by Claude, and clobbering
#      it on every postCreate would lose state.
#   4. ~/.claude exists but is read-only. Helper should fail loudly so the
#      user knows their environment is broken instead of producing a half-
#      wired install.
# Runs inside the built container so it uses the real installed helper.

set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

HELPER="/opt/claude-code-passthrough/link-credentials.sh"

# Synthesize an isolated staging dir with a working credentials/account
# pair plus a fake HOME, then drop a copy of the helper next to it so
# SELF_DIR resolves to the synthesized dir (not the real install).
prepare_staging() {
	local staging_dir="$1"
	mkdir -p "${staging_dir}/home/.claude"
	cp /opt/claude-code-passthrough/options.env "${staging_dir}/options.env"
	printf 'fake-credentials' >"${staging_dir}/.credentials.json"
	printf '{"fake":"account"}' >"${staging_dir}/.claude.json"
	cp "${HELPER}" "${staging_dir}/link-credentials.sh"
}

run_helper() {
	local staging_dir="$1"
	HOME="${staging_dir}/home" bash "${staging_dir}/link-credentials.sh"
}

check "helper replaces a pre-existing regular file with the symlink" \
	bash -c '
		set -e
		tmp="$(mktemp -d)"
		trap "chmod -R u+rwX \"${tmp}\" 2>/dev/null; rm -rf \"${tmp}\"" EXIT
		'"$(declare -f prepare_staging run_helper)"'
		prepare_staging "${tmp}"
		printf "stale-local-copy" >"${tmp}/home/.claude/.credentials.json"
		run_helper "${tmp}"
		[ -L "${tmp}/home/.claude/.credentials.json" ]
		[ "$(readlink "${tmp}/home/.claude/.credentials.json")" = "${tmp}/.credentials.json" ]
	'

check "helper replaces a stale symlink pointing elsewhere" \
	bash -c '
		set -e
		tmp="$(mktemp -d)"
		trap "chmod -R u+rwX \"${tmp}\" 2>/dev/null; rm -rf \"${tmp}\"" EXIT
		'"$(declare -f prepare_staging run_helper)"'
		prepare_staging "${tmp}"
		ln -s /nonexistent/elsewhere "${tmp}/home/.claude/.credentials.json"
		run_helper "${tmp}"
		[ "$(readlink "${tmp}/home/.claude/.credentials.json")" = "${tmp}/.credentials.json" ]
	'

check "helper preserves a pre-existing ~/.claude.json (container-local state)" \
	bash -c '
		set -e
		tmp="$(mktemp -d)"
		trap "chmod -R u+rwX \"${tmp}\" 2>/dev/null; rm -rf \"${tmp}\"" EXIT
		'"$(declare -f prepare_staging run_helper)"'
		prepare_staging "${tmp}"
		printf "{\"container\":\"local\"}" >"${tmp}/home/.claude.json"
		run_helper "${tmp}"
		# File must still be a regular file with the original contents.
		[ -f "${tmp}/home/.claude.json" ] && [ ! -L "${tmp}/home/.claude.json" ]
		[ "$(cat "${tmp}/home/.claude.json")" = "{\"container\":\"local\"}" ]
	'

check "helper fails loudly when ~/.claude is read-only" \
	bash -c '
		set -e
		tmp="$(mktemp -d)"
		trap "chmod -R u+rwX \"${tmp}\" 2>/dev/null; rm -rf \"${tmp}\"" EXIT
		'"$(declare -f prepare_staging run_helper)"'
		prepare_staging "${tmp}"
		# Drop the pre-created ~/.claude and replace with a read-only one
		# so the symlink creation has to fail.
		rm -rf "${tmp}/home/.claude"
		mkdir "${tmp}/home/.claude"
		chmod a-w "${tmp}/home/.claude"
		if run_helper "${tmp}" >/dev/null 2>&1; then
			echo "expected non-zero exit, got 0" >&2
			exit 1
		fi
	'

reportResults
