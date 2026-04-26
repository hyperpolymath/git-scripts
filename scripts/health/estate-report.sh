#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# health/estate-report.sh — run the read-only audits in sequence and
# aggregate them into a single Markdown + A2ML report.
#
# Composed audits:
#   * audit_contractiles.sh   — contractile completeness
#   * project-tabs-audit.sh   — repo About metadata
#   * wiki-audit.sh           — wiki status (key repos only by default)
#   * sync/mirror-check.sh    — GitHub-as-source-of-truth verifier
#
# Self-healing/safe behaviour:
#   * Any failing sub-audit is logged + skipped — the report still completes.
#   * Outputs are timestamped under $GS_REPORT_DIR.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/../lib/common.sh"
SCRIPTS_ROOT="${SCRIPT_DIR%/health}"

GS_SCRIPT_NAME="estate-report"
GS_HELP_TEXT="Usage: estate-report.sh [--full] [--help]

Runs the read-only audits and aggregates them into a single report.

Options:
      --full       Audit ALL repos (slower); default uses each script's fast mode.
  -j, --jobs N     Parallel workers (default ${GS_PARALLEL})
  -v, --verbose
  -q, --quiet
  -h, --help
"

gs::strict
gs::install_trap
gs::install_trap_summary

OPT_FULL=0
while (( $# > 0 )); do
    case "$1" in
        --full)       OPT_FULL=1 ;;
        -j|--jobs)    GS_PARALLEL="${2:?}"; shift ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        -h|--help)    printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)            gs::die "unknown flag: $1" ;;
    esac
    shift
done

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
out_md="${GS_REPORT_DIR}/${stamp}-estate-report.md"
out_log="${GS_REPORT_DIR}/${stamp}-estate-report.log"
gs::info "writing ${out_md}"

declare -i FAILURES=0
run_section() {
    local title="$1"; shift
    gs::banner "${title}"
    {
        printf '\n## %s\n\n```\n' "${title}"
        if "$@" 2>&1; then
            printf '```\n'
        else
            local ec=$?
            printf '\n_(audit exited with code %d — see log)_\n```\n' "${ec}"
            (( FAILURES++ )) || true
        fi
    } >> "${out_md}"
}

{
    printf '# Hyperpolymath Estate Health Report\n\n'
    printf 'Generated: %s\n\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf 'Estate root: `%s`\n' "${GS_REPOS_DIR}"
} > "${out_md}"

# Each section tolerates failure; the report still completes.
gh_args=()
(( OPT_FULL )) || gh_args+=(--key-only)

run_section "Contractile audit" \
    bash "${SCRIPTS_ROOT}/audit_contractiles.sh" --report

run_section "GitHub project metadata" \
    bash "${SCRIPTS_ROOT}/project-tabs-audit.sh" || true

run_section "Wiki status" \
    bash "${SCRIPTS_ROOT}/wiki-audit.sh" "${gh_args[@]:---summary}" || true

run_section "Mirror policy" \
    bash "${SCRIPTS_ROOT}/sync/mirror-check.sh" || true

gs::banner "Estate report complete"
gs::info "Markdown: ${out_md}"
gs::info "Sub-audit failures: ${FAILURES}"

(( FAILURES > 0 )) && exit 2
exit 0
