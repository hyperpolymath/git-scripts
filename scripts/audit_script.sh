#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# audit_script.sh — secret-scan + Dependabot-alert audit across the estate.
#
# Combines local gitleaks scans with the per-repo Dependabot alert count
# from the GitHub API. Outputs a Markdown table.
#
# Self-healing/safe behaviour:
#   * Gracefully degrades when gitleaks is missing (warning, not crash).
#   * Uses gh API via the lib's retrying wrapper; rate-limit-aware.
#   * Per-repo failure does not abort the run.
#   * Honours $GH_TOKEN / GITHUB_TOKEN; falls back to gh CLI auth.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="audit_script"
GS_HELP_TEXT="Usage: audit_script.sh [--owner X] [--report] [--help]

Per-repo gitleaks + Dependabot alert audit. Prints a Markdown table.
"

gs::strict
gs::install_trap
gs::install_trap_summary

OWNER="hyperpolymath"
OPT_REPORT=0
while (( $# > 0 )); do
    case "$1" in
        --owner)      OWNER="${2:?}"; shift ;;
        --report)     OPT_REPORT=1 ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        -h|--help)    printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)            gs::die "unknown flag: $1" ;;
    esac
    shift
done

gs::need jq
gs::gh_check
HAVE_GITLEAKS=0
gs::have gitleaks && HAVE_GITLEAKS=1
(( HAVE_GITLEAKS )) || gs::warn "gitleaks not installed; secret-scan column will be 'skip'"

REPORT_FILE=""
(( OPT_REPORT )) && { REPORT_FILE="$(gs::report_path)"; gs::info "report: ${REPORT_FILE}"; }

CONFIG_FILE="${GS_REPOS_DIR}/gitleaks_config.toml"
GLOBAL_IGNORE="${GS_REPOS_DIR}/global_gitleaksignore"
[[ -f "${GLOBAL_IGNORE}" ]] || touch "${GLOBAL_IGNORE}"

gs::banner "Estate secret-scan + Dependabot audit"

printf '| Repo | Gitleaks | Dependabot (Crit/High) | Status |\n'
printf '| --- | --- | --- | --- |\n'

while IFS= read -r repo_path; do
    repo_name="$(basename -- "${repo_path}")"

    # Gitleaks.
    leak_count=skip
    if (( HAVE_GITLEAKS )); then
        report="$(gs::mktemp)"
        if gitleaks detect --source "${repo_path}" --no-git \
            ${CONFIG_FILE:+--config "${CONFIG_FILE}"} \
            --gitleaks-ignore-path "${GLOBAL_IGNORE}" \
            --report-path "${report}" --report-format json \
            >/dev/null 2>&1; then
            leak_count="$(grep -c '"Fingerprint"' "${report}" 2>/dev/null || echo 0)"
        else
            leak_count="0"
        fi
    fi

    # Dependabot.
    dep_status="N/A"
    alerts="$(gs::gh api "/repos/${OWNER}/${repo_name}/dependabot/alerts?state=open" 2>/dev/null || true)"
    if [[ -n "${alerts}" ]] && echo "${alerts}" | jq -e 'type == "array"' >/dev/null 2>&1; then
        crit="$(echo "${alerts}" | jq '[.[] | select(.security_advisory.severity == "critical")] | length')"
        high="$(echo "${alerts}" | jq '[.[] | select(.security_advisory.severity == "high")]     | length')"
        dep_status="${crit}/${high}"
    fi

    # Status.
    status="OK"
    if [[ "${leak_count}" =~ ^[0-9]+$ ]] && (( leak_count > 0 )); then
        status="Action Required (Gitleaks: ${leak_count})"
    elif [[ "${dep_status}" =~ ^[0-9]+/[0-9]+$ ]]; then
        c="${dep_status%/*}"; h="${dep_status#*/}"
        if (( c > 0 || h > 0 )); then
            status="Action Required (Dependabot: ${dep_status})"
        fi
    fi

    printf '| %s | %s | %s | %s |\n' "${repo_name}" "${leak_count}" "${dep_status}" "${status}"
    if [[ -n "${REPORT_FILE}" ]]; then
        gs::report_add "${REPORT_FILE}" \
            "repo = \"${repo_name}\"" \
            "leaks = \"${leak_count}\"" \
            "dependabot = \"${dep_status}\"" \
            "status = \"${status}\""
    fi
done < <(gs::repos)

gs::info "done"
[[ -n "${REPORT_FILE}" ]] && gs::info "report: ${REPORT_FILE}"
exit 0
