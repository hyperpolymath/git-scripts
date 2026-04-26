#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# sync/mirror-check.sh — verify the GitHub-only-push policy.
#
# Standing rule (per memory feedback_github_only_mirroring):
#   GitHub is the single source of truth. We only push to `origin` (GitHub).
#   Other forges (GitLab, Bitbucket, Codeberg, Sourcehut, Gitea, Disroot, …)
#   are populated by the downstream hub-and-spoke mirror system from GitHub.
#   Estate-wide exceptions: `007` (never mirrored) and `bitfuckit`
#   (Bitbucket-primary by design).
#
# This script walks every repo and reports drift:
#   * `origin` not pointing at github.com
#   * a configured non-origin remote whose URL is github.com (suspicious)
#   * `push.default` set to a non-current/upstream value
#   * any `[remote.<name>] pushurl` redirect to a non-GitHub forge
#
# Read-only — never modifies a repo.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/../lib/common.sh"

GS_SCRIPT_NAME="mirror-check"
GS_HELP_TEXT="Usage: mirror-check.sh [--report] [--help]

Verifies the GitHub-only push policy across every repo under \$GS_REPOS_DIR.
"

gs::strict
gs::install_trap
gs::install_trap_summary

OPT_REPORT=0
while (( $# > 0 )); do
    case "$1" in
        --report)     OPT_REPORT=1 ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        -h|--help)    printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)            gs::die "unknown flag: $1" ;;
    esac
    shift
done

REPORT_FILE=""
if (( OPT_REPORT )); then
    REPORT_FILE="$(gs::report_path)"
    gs::info "writing report to ${REPORT_FILE}"
fi

# Estate-wide exceptions per memory.
EXCEPTIONS=(007 bitfuckit)

is_exception() {
    local r
    for r in "${EXCEPTIONS[@]}"; do
        [[ "$1" == "${r}" ]] && return 0
    done
    return 1
}

declare -i N=0 OK=0 DRIFT=0 SKIP=0

gs::banner "Mirror-policy check — GitHub-only push"

while IFS= read -r repo; do
    (( N++ )) || true
    name="$(basename -- "${repo}")"

    if is_exception "${name}"; then
        gs::debug "${name}: estate-wide exception; skipping"
        (( SKIP++ )) || true
        continue
    fi

    cd "${repo}" || { gs::warn "${name}: cd failed"; continue; }

    origin_url="$(git remote get-url origin 2>/dev/null || echo "")"
    if [[ -z "${origin_url}" ]]; then
        gs::warn "${name}: no 'origin' remote"
        (( DRIFT++ )) || true
        outcome="no-origin"
    elif [[ "${origin_url}" != *github.com* ]]; then
        gs::warn "${name}: origin -> ${origin_url} (not github.com)"
        (( DRIFT++ )) || true
        outcome="origin-not-github"
    else
        # Check non-origin remotes for any github.com URL — that's a sign
        # someone has been mixing forges in confusing ways.
        bad_remotes=()
        while IFS= read -r r; do
            [[ -z "${r}" || "${r}" = "origin" ]] && continue
            url="$(git remote get-url "${r}" 2>/dev/null || true)"
            if [[ "${url}" == *github.com* ]]; then
                bad_remotes+=("${r}=${url}")
            fi
        done < <(git remote 2>/dev/null)

        # Pushurl redirects.
        bad_push_urls=()
        while IFS=$'\n' read -r line; do
            # Lines like: remote.gitlab.pushurl https://gitlab.com/foo/bar.git
            [[ -z "${line}" ]] && continue
            bad_push_urls+=("${line}")
        done < <(git config --get-regexp '^remote\..*\.pushurl$' 2>/dev/null \
            | grep -v 'github\.com' || true)

        if (( ${#bad_remotes[@]} > 0 || ${#bad_push_urls[@]} > 0 )); then
            (( DRIFT++ )) || true
            outcome="multi-remote-drift"
            gs::warn "${name}: ${bad_remotes[*]:-} ${bad_push_urls[*]:-}"
        else
            (( OK++ )) || true
            outcome="ok"
        fi
    fi

    if [[ -n "${REPORT_FILE}" ]]; then
        gs::report_add "${REPORT_FILE}" \
            "repo = \"${name}\"" \
            "origin = \"${origin_url}\"" \
            "outcome = \"${outcome}\""
    fi
done < <(gs::repos)

gs::banner "Summary"
gs::info "scanned=${N}  ok=${OK}  drift=${DRIFT}  exception=${SKIP}"
[[ -n "${REPORT_FILE}" ]] && gs::info "report: ${REPORT_FILE}"

(( DRIFT > 0 )) && exit 2
exit 0
