#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# fix/all.sh — run every fixer in sequence against a single repo.
#
# Replaces the legacy fix-security-issues.sh. Same idea, but uses the
# common library (dry-run aware, stops on first hard error, summarises at
# the end), and the underlying fixers all default to REPORT-ONLY mode.
#
# Usage:
#   fix/all.sh [--apply-expect] [--dry-run] <repo-path>

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/../lib/common.sh"
SCRIPTS_ROOT="${SCRIPT_DIR%/fix}"

GS_SCRIPT_NAME="fix-all"
GS_HELP_TEXT="Usage: fix/all.sh [--apply-expect] [--dry-run] <repo-path>

Runs every fixer (PanicPath, innerHTML/XSS) against <repo-path>.

Options:
      --apply-expect   Pass through to fix-unwrap-to-match (anti-pattern; off by default)
  -n, --dry-run        Show what would change
  -y, --yes            Skip confirmation prompts in fixers
  -v, --verbose
  -q, --quiet
  -h, --help
"

gs::strict
gs::install_trap
gs::install_trap_summary

OPT_APPLY_EXPECT=0
PASSTHRU=()
REPO_PATH=""

while (( $# > 0 )); do
    case "$1" in
        --apply-expect) OPT_APPLY_EXPECT=1; PASSTHRU+=("--apply-expect") ;;
        -n|--dry-run)   GS_DRY_RUN=1; PASSTHRU+=("--dry-run") ;;
        -y|--yes)       GS_YES=1; PASSTHRU+=("--yes") ;;
        -v|--verbose)   GS_LOG_LEVEL=debug ;;
        -q|--quiet)     GS_LOG_LEVEL=warn ;;
        -h|--help)      printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)              [[ -z "${REPO_PATH}" ]] && REPO_PATH="$1" || gs::die "unexpected: $1" ;;
    esac
    shift
done

[[ -z "${REPO_PATH}" ]] && gs::die "repo path required"
[[ -d "${REPO_PATH}" ]] || gs::die "not a directory: ${REPO_PATH}"

gs::banner "Composite fixer — ${REPO_PATH}"

declare -i FAILED=0
run_step() {
    local label="$1"; shift
    gs::info "running ${label}..."
    if ! "$@"; then
        gs::error "${label} failed"
        (( FAILED++ )) || true
    fi
}

run_step "PanicPath (.unwrap)" \
    bash "${SCRIPTS_ROOT}/fix-unwrap-to-match.sh" "${PASSTHRU[@]}" "${REPO_PATH}"

run_step "innerHTML/XSS" \
    bash "${SCRIPTS_ROOT}/fix-innerhtml.sh" "${PASSTHRU[@]}" "${REPO_PATH}"

gs::banner "Summary"
gs::info "step failures: ${FAILED}"
gs::info "Next: review with 'git diff' and run language-appropriate type/lint checks."

(( FAILED > 0 )) && exit 1
exit 0
