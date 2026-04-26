#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# fix-innerhtml.sh — replace bare `.innerHTML = "text"` with `.textContent`,
# and annotate every other XSS-prone DOM-write site with a SECURITY comment
# so the human reviewer is forced to look.
#
# Self-healing/safe behaviour:
#   * Per-file snapshot before any edit; auto-rollback on sed failure.
#   * Skips minified / vendor / node_modules paths.
#   * --dry-run: report only, no writes.
#   * Idempotent: existing SECURITY annotations are not duplicated.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="fix-innerhtml"
GS_HELP_TEXT="Usage: fix-innerhtml.sh [--dry-run] <repo-path> [finding-json]

Annotates and where safe rewrites XSS-prone DOM writes (innerHTML, outerHTML,
document.write) in JS/TS/JSX/ReScript files.
"

gs::strict
gs::install_trap
gs::install_trap_summary

REPO_PATH=""
FINDING_JSON=""
while (( $# > 0 )); do
    case "$1" in
        -n|--dry-run) GS_DRY_RUN=1 ;;
        -y|--yes)     GS_YES=1 ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        -h|--help)    printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)
            if   [[ -z "${REPO_PATH}" ]];     then REPO_PATH="$1"
            elif [[ -z "${FINDING_JSON}" ]];  then FINDING_JSON="$1"
            else gs::die "unexpected: $1"
            fi
            ;;
    esac
    shift
done
[[ -z "${REPO_PATH}" ]] && gs::die "repo path required"
[[ -d "${REPO_PATH}" ]] || gs::die "not a directory: ${REPO_PATH}"

# Optional historical lib for vendor excludes.
if [[ -f "${SCRIPT_DIR}/../lib/third-party-excludes.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../lib/third-party-excludes.sh"
fi
EXCLUDES=("${FIND_THIRD_PARTY_EXCLUDES[@]:-}")

gs::banner "innerHTML/XSS sweep"
gs::info "repo=${REPO_PATH}  dry-run=${GS_DRY_RUN}"
[[ -n "${FINDING_JSON}" ]] && gs::info "finding=${FINDING_JSON}"

REPORT_FILE="$(gs::report_path)"
declare -i FILE_HITS=0 EDITS=0

annotate_pattern() {
    # $1=file  $2=regex (sed-style)  $3=comment-line (without leading //)
    local file="$1" regex="$2" comment="$3"
    grep -qP "${regex}" "${file}" 2>/dev/null || return 1
    grep -q "SECURITY:.*${comment%% *}" "${file}" 2>/dev/null && return 0   # already done

    if gs::is_dry_run; then
        gs::info "DRY-RUN: would annotate ${file##*/} for ${comment%% *}"
        return 0
    fi
    local snap; snap="$(gs::snapshot "${file}")"
    if ! sed -i "/${regex}/i\\    // SECURITY: ${comment}" "${file}" 2>/dev/null; then
        gs::error "sed failed; rolling back ${file}"
        gs::rollback "${snap}" "${file}"
        return 1
    fi
    return 0
}

while IFS= read -r -d '' file; do
    [[ "${file}" == *.min.js || "${file}" == *.min.css ]] && continue
    [[ "${file}" == */node_modules/* ]] && continue
    rel="${file#${REPO_PATH}/}"
    edited=0

    # Pattern 1 — `.innerHTML = "literal text"` (no markup): rewrite to .textContent.
    if grep -qP '\.innerHTML\s*=' "${file}" 2>/dev/null; then
        if grep -qP '\.innerHTML\s*=\s*[^<>]*$' "${file}"; then
            if gs::is_dry_run; then
                gs::info "DRY-RUN: would rewrite text-only innerHTML in ${rel}"
            else
                snap="$(gs::snapshot "${file}")"
                if sed -i -E '/\.innerHTML\s*=.*[<>]/!s/\.innerHTML\s*=/.textContent =/' "${file}"; then
                    edited=1
                else
                    gs::rollback "${snap}" "${file}"
                fi
            fi
        fi
        # Annotate any remaining innerHTML lines that contain markup.
        annotate_pattern "${file}" '\.innerHTML\s*=.*[<>]' \
            "innerHTML with markup is XSS-prone — sanitize input or use DOM API" && edited=1
    fi

    annotate_pattern "${file}" '\.innerHTML\s*\+=' \
        "innerHTML concatenation is XSS-prone — use DOM createElement/appendChild" && edited=1
    annotate_pattern "${file}" '\.outerHTML\s*=' \
        "outerHTML assignment is XSS-prone — use DOM API instead" && edited=1
    annotate_pattern "${file}" 'document\.write\s*\(' \
        "document.write is an XSS vector — use DOM API instead" && edited=1

    if (( edited )); then
        (( FILE_HITS++ )) || true
        (( EDITS++ ))     || true
        gs::info "${rel}: annotated/rewrote"
        gs::report_add "${REPORT_FILE}" "file = \"${rel}\""
    fi
done < <(find "${REPO_PATH}" -type f \
    \( -name '*.js' -o -name '*.mjs' -o -name '*.jsx' -o -name '*.res' \) \
    -not -path '*/.git/*' -not -path '*/node_modules/*' \
    "${EXCLUDES[@]}" -not -name '*.min.js' -print0 2>/dev/null)

gs::info "files touched=${FILE_HITS}"
gs::info "report: ${REPORT_FILE}"
exit 0
