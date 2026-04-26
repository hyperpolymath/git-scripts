#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# DEPRECATED — use fix/all.sh.
#
# This thin wrapper now forwards to fix/all.sh, which uses the shared library
# (dry-run, snapshots, summaries) and runs every fixer in sequence.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
echo "[deprecated] fix-security-issues.sh -> fix/all.sh" >&2
exec "${SCRIPT_DIR}/fix/all.sh" "$@"
