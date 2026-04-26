#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# DEPRECATED — replaced by health/gh-doctor.sh.
#
# This file used to be a printed tutorial. It has been replaced with a real
# diagnostic. Stub kept so the Elixir TUI's hardcoded reference
# (lib/script_manager/gh_cli.ex) still resolves.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
echo "[deprecated] USE-GH-CLI.sh -> health/gh-doctor.sh" >&2
exec "${SCRIPT_DIR}/health/gh-doctor.sh" "$@"
