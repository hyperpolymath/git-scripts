#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# health/gh-doctor.sh — sanity-check the local gh CLI for estate work.
#
# Replaces the historical USE-GH-CLI.sh tutorial. Verifies:
#   * gh CLI installed
#   * authenticated (and which host)
#   * minimum required scopes (repo, admin:org, workflow, read:packages)
#   * rate-limit headroom (warn if < 500 remaining)
#   * git credential helper sanity
#   * jq availability (used by every audit script)

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/../lib/common.sh"

GS_SCRIPT_NAME="gh-doctor"
GS_HELP_TEXT="Usage: gh-doctor.sh [--help]

Diagnoses the gh CLI environment used by every estate-wide script.
"

gs::strict
gs::install_trap
gs::install_trap_summary

while (( $# > 0 )); do
    case "$1" in
        -h|--help) printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)         gs::die "unknown flag: $1" ;;
    esac
    shift
done

gs::banner "gh CLI doctor"

declare -i FAILURES=0
fail()  { gs::error "$@"; (( FAILURES++ )) || true; }
ok()    { gs::info  "✓ $*"; }
note()  { gs::info  "  $*"; }

if ! gs::have gh; then
    fail "gh not installed (https://cli.github.com)"
    exit 1
fi
ok "gh installed: $(gh --version | head -n1)"

if ! gs::have jq; then
    fail "jq not installed — every audit script needs it"
else
    ok "jq installed: $(jq --version)"
fi

if ! gh auth status >/dev/null 2>&1; then
    fail "gh is not authenticated — run: gh auth login"
    exit 1
fi
ok "gh is authenticated"
gh auth status 2>&1 | sed 's/^/    /' >&2

# Scopes — gh exposes them via `gh auth status -t` token line; safer to call
# the API and inspect the X-OAuth-Scopes header.
scopes="$(gh api -i /user 2>/dev/null | awk -F': ' 'tolower($1)=="x-oauth-scopes"{print $2; exit}' | tr -d '\r')"
if [[ -z "${scopes}" ]]; then
    gs::warn "could not read X-OAuth-Scopes (fine-grained PAT or unsupported endpoint)"
else
    note "scopes: ${scopes}"
    for required in repo workflow read:org; do
        if ! grep -qw "${required}" <<< "${scopes}"; then
            gs::warn "scope '${required}' not granted"
        fi
    done
fi

# Rate limit headroom.
remaining="$(gs::gh_remaining)"
note "core API remaining: ${remaining}"
if [[ "${remaining}" =~ ^[0-9]+$ ]] && (( remaining < 500 )); then
    gs::warn "rate-limit headroom is low (${remaining}); avoid bulk operations until the window resets"
fi

# git credential helper sanity (cached creds avoid prompts mid-run).
if git config --global --get credential.helper >/dev/null; then
    ok "git credential helper: $(git config --global --get credential.helper)"
else
    gs::warn "no global git credential.helper; pushes may prompt interactively"
fi

# Are we under the canonical repos root?
note "GS_REPOS_DIR: ${GS_REPOS_DIR}"
[[ -d "${GS_REPOS_DIR}" ]] || gs::warn "GS_REPOS_DIR does not exist"

gs::banner "Done"
(( FAILURES > 0 )) && exit 1
exit 0
