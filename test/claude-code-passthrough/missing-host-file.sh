#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Tim Cane
#
# Scenario: missing-host-file — exercises link-credentials.sh against
# a synthesized staging directory in two failure modes:
#   1. Staging path entirely absent (host file never existed AND Docker
#      didn't create a stand-in). Helper should warn and exit 0.
#   2. Staging path is a directory (Docker auto-mkdir'd because the
#      host file was missing at first build). Helper should exit 1
#      with the actionable error message.
# This runs inside the built container so it uses the real helper as
# installed, not a copy.

set -euo pipefail

# shellcheck source=/dev/null
source dev-container-features-test-lib

HELPER="/opt/claude-code-passthrough/link-credentials.sh"

run_helper_with_staging() {
	local staging_dir="$1" mode="$2"
	# Synthesize a staging dir with only options.env, then optionally
	# create the credentials/account paths in the requested shape.
	mkdir -p "${staging_dir}"
	cp /opt/claude-code-passthrough/options.env "${staging_dir}/options.env"

	case "${mode}" in
		absent) ;;  # leave both paths missing
		directory)
			mkdir -p "${staging_dir}/.credentials.json"
			mkdir -p "${staging_dir}/.claude.json"
			;;
	esac

	# Drop a copy of the helper into the synthesized dir so SELF_DIR
	# resolves to our staging, not the real one.
	cp "${HELPER}" "${staging_dir}/link-credentials.sh"
	HOME="${staging_dir}/home" bash "${staging_dir}/link-credentials.sh"
}

check "helper skips gracefully when staging files are absent" \
	bash -c '
		set -e
		tmp="$(mktemp -d)"
		trap "rm -rf \"${tmp}\"" EXIT
		'"$(declare -f run_helper_with_staging)"'
		run_helper_with_staging "${tmp}" absent
	'

check "helper errors when staging path is a directory (Docker auto-mkdir)" \
	bash -c '
		set -e
		tmp="$(mktemp -d)"
		trap "rm -rf \"${tmp}\"" EXIT
		'"$(declare -f run_helper_with_staging)"'
		if run_helper_with_staging "${tmp}" directory >/dev/null 2>&1; then
			echo "expected non-zero exit, got 0" >&2
			exit 1
		fi
	'

reportResults
