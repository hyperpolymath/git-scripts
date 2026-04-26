#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# verify.sh — local-vs-origin sync-status verifier.
#
# Walks the configured REPOS list (or every git repo under $GS_REPOS_DIR
# with --all) and prints a Markdown table of each one's local HEAD vs
# origin/<branch>.
#
# Read-only — never fetches, never writes. Pair with `update_repos.sh` if
# you need to sync first.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="verify"
GS_HELP_TEXT="Usage: verify.sh [--all] [--help]

Print a sync-status table for the configured (or every) repo. Read-only.
"

gs::strict
gs::install_trap
gs::install_trap_summary

CONFIG_FILE="${SCRIPT_DIR}/../config/repos.config"
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"
: "${REPOS:=}"
: "${BASE_DIR:=${GS_REPOS_DIR}}"

OPT_ALL=0
while (( $# > 0 )); do
    case "$1" in
        --all)        OPT_ALL=1 ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        -h|--help)    printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)            gs::die "unknown flag: $1" ;;
    esac
    shift
done

declare -a TARGETS=()
if (( OPT_ALL )); then
    while IFS= read -r r; do TARGETS+=("${r}"); done < <(gs::repos)
else
    if [[ ${#REPOS[@]:-0} -eq 0 ]]; then
        gs::die "no REPOS configured (use --all)"
    fi
    for r in "${REPOS[@]}"; do TARGETS+=("${BASE_DIR}/${r}"); done
fi

printf '| Repository | Branch | Local HEAD | Origin HEAD | In sync? |\n'
printf '| --- | --- | --- | --- | --- |\n'

declare -i N=0 OK=0 DRIFT=0 SKIP=0
for repo in "${TARGETS[@]}"; do
    name="$(basename -- "${repo}")"
    if [[ ! -d "${repo}/.git" ]]; then
        printf '| %s | _missing_ | - | - | skip |\n' "${name}"
        (( SKIP++ )) || true
        continue
    fi
    cd "${repo}" || { (( SKIP++ )) || true; continue; }
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
    local_msg="$(git log -1 --pretty=format:'%s' 2>/dev/null || echo "")"
    if git rev-parse --verify "origin/${branch}" >/dev/null 2>&1; then
        remote_msg="$(git log -1 --pretty=format:'%s' "origin/${branch}" 2>/dev/null || echo "")"
    else
        remote_msg="(no upstream)"
    fi
    sync="No"
    [[ "${local_msg}" == "${remote_msg}" ]] && sync="Yes"
    [[ "${sync}" = "Yes" ]] && (( OK++ )) || (( DRIFT++ )) || true
    (( N++ )) || true
    printf '| %s | %s | %.60s | %.60s | %s |\n' \
        "${name}" "${branch}" "${local_msg}" "${remote_msg}" "${sync}"
done

gs::info "scanned=${N}  in-sync=${OK}  drift=${DRIFT}  skipped=${SKIP}"
exit 0
