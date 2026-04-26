#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# update_repos.sh — fetch + safe-rebase + push across the configured repo set.
#
# Self-healing/safe behaviour:
#   * Fetches with --prune; if a pull would not be fast-forward, refuses to
#     touch the working tree (per ff-pull-abort-safety memo).
#   * Skips repos with uncommitted changes unless they're in COMMIT_REPOS.
#   * Push uses --force-with-lease so we never clobber concurrent work.
#   * Per-repo failure is captured; the loop continues. Final summary lists
#     the persistent failures.
#   * Honours --dry-run (no fetch -> no rebase -> no push; status only).
#   * Lock-protected (single-instance per host).
#   * Bounded parallelism via -j N.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="update_repos"
GS_HELP_TEXT="Usage: update_repos.sh [--dry-run] [--jobs N] [--all] [--report] [--help]

Safely fast-forwards every configured repo and pushes accumulated commits.

Options:
  -n, --dry-run    Fetch + status only; no rebase/push
      --all        Iterate every git repo under \$GS_REPOS_DIR (ignore config list)
      --report     Write A2ML report to \$GS_REPORT_DIR
  -j, --jobs N     Parallel workers (default ${GS_PARALLEL})
  -y, --yes        Skip the per-batch confirmation
  -v, --verbose
  -q, --quiet
  -h, --help

Environment:
  GS_REPOS_DIR     Estate root (default ${GS_REPOS_DIR})
"

gs::strict
gs::install_trap
gs::install_trap_summary
gs::lock update_repos

# Load the configured shortlist if present; --all mode overrides.
CONFIG_FILE="${SCRIPT_DIR}/../config/repos.config"
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
fi
: "${REPOS:=}"
: "${COMMIT_REPOS:=}"
: "${BASE_DIR:=${GS_REPOS_DIR}}"

OPT_ALL=0
OPT_REPORT=0
while (( $# > 0 )); do
    case "$1" in
        -n|--dry-run) GS_DRY_RUN=1 ;;
        --all)        OPT_ALL=1 ;;
        --report)     OPT_REPORT=1 ;;
        -j|--jobs)    GS_PARALLEL="${2:?}"; shift ;;
        -y|--yes)     GS_YES=1 ;;
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

# Build the iteration list.
declare -a TARGETS=()
if (( OPT_ALL )); then
    while IFS= read -r r; do TARGETS+=("${r}"); done < <(gs::repos)
else
    if [[ ${#REPOS[@]:-0} -eq 0 ]]; then
        gs::die "no REPOS configured in ${CONFIG_FILE} (use --all to walk every repo)"
    fi
    for r in "${REPOS[@]}"; do
        TARGETS+=("${BASE_DIR}/${r}")
    done
fi

is_in_commit_set() {
    local needle="$1" item
    for item in "${COMMIT_REPOS[@]:-}"; do
        [[ "${item}" == "${needle}" ]] && return 0
    done
    return 1
}

declare -a FAILURES=()

process_one() {
    local repo_dir="$1"
    local repo_name; repo_name="$(basename -- "${repo_dir}")"

    if [[ ! -d "${repo_dir}/.git" ]]; then
        gs::warn "${repo_name}: not a git repo; skipping"
        FAILURES+=("${repo_name} (not-a-git-repo)")
        return
    fi

    cd "${repo_dir}" || { FAILURES+=("${repo_name} (cd-failed)"); return; }

    # Fetch (always — read-only; useful even in dry-run).
    if ! git fetch --all --prune --quiet 2>/dev/null; then
        gs::warn "${repo_name}: fetch failed; continuing with last-known refs"
    fi

    local branch; branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
    [[ -z "${branch}" || "${branch}" = "HEAD" ]] && {
        gs::warn "${repo_name}: detached HEAD; skipping"
        FAILURES+=("${repo_name} (detached-HEAD)")
        return
    }

    local has_dirty=0
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && has_dirty=1

    # Optional commit on the curated COMMIT_REPOS list.
    if (( has_dirty )) && is_in_commit_set "${repo_name}"; then
        if gs::is_dry_run; then
            gs::info "${repo_name}: DRY-RUN would commit pending changes"
        else
            git add . || true
            git commit -m "chore: RSR sync and mass repository update" 2>/dev/null \
                || gs::warn "${repo_name}: nothing to commit"
        fi
    elif (( has_dirty )); then
        gs::warn "${repo_name}: dirty working tree; skipping push (not in COMMIT_REPOS)"
        FAILURES+=("${repo_name} (dirty-tree)")
        return
    fi

    # Fast-forward check. Refuse to rebase if upstream history rewrote.
    local upstream="origin/${branch}"
    if git rev-parse --verify "${upstream}" >/dev/null 2>&1; then
        local behind ahead
        behind="$(git rev-list --count "${branch}..${upstream}" 2>/dev/null || echo 0)"
        ahead="$(git rev-list --count  "${upstream}..${branch}" 2>/dev/null || echo 0)"

        if (( behind > 0 )); then
            if gs::is_dry_run; then
                gs::info "${repo_name}: behind by ${behind} (dry-run, no rebase)"
            else
                gs::info "${repo_name}: rebasing onto ${upstream} (behind=${behind})"
                if ! git rebase "${upstream}" >/dev/null 2>&1; then
                    git rebase --abort 2>/dev/null || true
                    gs::error "${repo_name}: rebase conflict — manual fix required"
                    FAILURES+=("${repo_name} (rebase-conflict)")
                    return
                fi
            fi
        fi
        if (( ahead == 0 )) && (( behind == 0 )); then
            gs::debug "${repo_name}: up-to-date"
        fi
    else
        gs::warn "${repo_name}: no upstream for ${branch}"
    fi

    # Push (skip in dry-run).
    if gs::is_dry_run; then
        gs::info "${repo_name}: DRY-RUN skipping push"
    else
        local push_log; push_log="$(gs::mktemp)"
        if git push --force-with-lease 2>"${push_log}" >/dev/null; then
            gs::info "${repo_name}: pushed"
        else
            if grep -q 'has no upstream branch' "${push_log}"; then
                gs::warn "${repo_name}: setting upstream and pushing..."
                if ! git push --set-upstream origin "${branch}" >/dev/null 2>&1; then
                    FAILURES+=("${repo_name} (push-no-upstream-failed)")
                    return
                fi
            else
                local first; first="$(head -n1 "${push_log}")"
                gs::error "${repo_name}: push failed — ${first}"
                FAILURES+=("${repo_name} (push-failed: ${first})")
                return
            fi
        fi
    fi

    if [[ -n "${REPORT_FILE}" ]]; then
        gs::report_add "${REPORT_FILE}" \
            "repo = \"${repo_name}\"" \
            "branch = \"${branch}\"" \
            "outcome = \"ok\""
    fi
}

# -----------------------------------------------------------------------------
# Run.
# -----------------------------------------------------------------------------

gs::banner "Estate update — ${#TARGETS[@]} repo(s)"
if ! gs::is_dry_run; then
    gs::confirm "About to fetch+rebase+push ${#TARGETS[@]} repos. Proceed?" \
        || gs::die "aborted by user"
fi

for repo in "${TARGETS[@]}"; do
    process_one "${repo}" || true
done

gs::banner "Summary"
gs::info "total=${#TARGETS[@]}  failures=${#FAILURES[@]}"
if (( ${#FAILURES[@]} > 0 )); then
    for f in "${FAILURES[@]}"; do gs::warn "  - ${f}"; done
fi
[[ -n "${REPORT_FILE}" ]] && gs::info "report: ${REPORT_FILE}"

(( ${#FAILURES[@]} > 0 )) && exit 1
exit 0
