#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# ownership_guard.sh — backwards-compat shim.
#
# The canonical implementation lives in `lib/common.sh` under `gs::`-prefixed
# names (gs::owner_allowed, gs::repo_owner_from_remote, gs::repo_allowed,
# gs::assert_owner_allowed). This file re-exports them under their legacy
# unprefixed names so existing `source` callers keep working.
#
# Public functions (legacy names — prefer the gs:: forms in new code):
#   owner_allowed <owner>            — return 0 if allowed, 1 otherwise
#   repo_owner_from_remote <path>    — print the GitHub owner of a local repo
#   repo_allowed <path>              — return 0 if a local repo's owner is allowed
#   assert_owner_allowed <owner>     — exit 78 if owner is not allowed

# Idempotent guard kept for source-twice safety.
[[ -n "${_OWNERSHIP_GUARD_LOADED:-}" ]] && return 0
_OWNERSHIP_GUARD_LOADED=1

__OG_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck disable=SC1091
. "${__OG_DIR}/common.sh"

owner_allowed()           { gs::owner_allowed "$@"; }
repo_owner_from_remote()  { gs::repo_owner_from_remote "$@"; }
repo_allowed()            { gs::repo_allowed "$@"; }
assert_owner_allowed()    { gs::assert_owner_allowed "$@"; }
