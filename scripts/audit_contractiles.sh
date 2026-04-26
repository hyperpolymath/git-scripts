#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# audit_contractiles.sh — estate-wide contractile-completeness audit.
#
# Walks every repo under $GS_REPOS_DIR and reports:
#   * presence/absence of each contractile verb (intend/trust/must/bust/adjust/dust)
#   * canonical location (.machine_readable/contractiles/<verb>/) vs drift
#   * K9 SVC integration (svc/k9 OR coordination.k9 OR workflow refs)
#   * accessibility-implementation hooks
#   * accessibility documentation
#
# Honours common.sh flags: -n/--dry-run, -j/--jobs N, -v/-q, -h/--help.
# Writes a structured A2ML report to $GS_REPORT_DIR.
#
# Note (2026-04-18 ADR): k9 lives at .machine_readable/svc/k9/, not inside
# contractiles/. Older repos have it under contractiles/k9/ — flagged as
# drift, not failure.
#
# Note (2026-04-18 ADR): `lust` is deprecated; absorbed into Intentfile.a2ml.
# Repos still carrying a separate lust/ directory are flagged as drift.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="audit_contractiles"
GS_HELP_TEXT="Usage: audit_contractiles.sh [--dry-run] [--jobs N] [--key-only] [--report] [--help]

Audits hyperpolymath repos for contractile-system completeness.

Options:
  -n, --dry-run    Read-only run (default — this script never writes anyway)
  -j, --jobs N     Parallel repo workers (default ${GS_PARALLEL})
      --key-only   Audit only the historical key-repo set (legacy fast-path)
      --report     Emit a structured A2ML report to \$GS_REPORT_DIR
  -v, --verbose    Show debug-level logging
  -q, --quiet      Only warnings/errors
  -h, --help       This message

Environment:
  GS_REPOS_DIR   Estate root (default ${GS_REPOS_DIR})
  GS_REPO_LIST   Optional file of one-repo-per-line filter list
"

gs::strict
gs::install_trap
gs::install_trap_summary

# Six canonical contractile verbs (post-2026-04-18; lust deprecated).
CANONICAL_VERBS=(intend trust must bust adjust dust)
LEGACY_DRIFT_VERBS=(lust)   # flag if found

# Legacy short-list — kept for backwards-compatible --key-only mode.
KEY_REPOS=(
    burble panll nextgen-databases rescript standards
)

OPT_KEY_ONLY=0
OPT_REPORT=0

# Hand-roll parsing because we have script-specific flags too.
while (( $# > 0 )); do
    case "$1" in
        -n|--dry-run) GS_DRY_RUN=1 ;;
        -j|--jobs)    GS_PARALLEL="${2:?}"; shift ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        --key-only)   OPT_KEY_ONLY=1 ;;
        --report)     OPT_REPORT=1 ;;
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

# -----------------------------------------------------------------------------
# Per-repo audit — returns a single line of TSV: repo<TAB>kind<TAB>detail
# -----------------------------------------------------------------------------

declare -i C_TOTAL=0
declare -i C_OK=0
declare -i C_DRIFT=0
declare -i C_MISSING=0

audit_repo() {
    local repo="$1"
    local name; name="$(basename -- "${repo}")"

    (( C_TOTAL++ )) || true

    if [[ ! -d "${repo}/.machine_readable/contractiles" ]]; then
        gs::warn "${name}: no contractiles directory"
        (( C_MISSING++ )) || true
        [[ -n "${REPORT_FILE}" ]] && \
            gs::report_add "${REPORT_FILE}" \
                "repo = \"${name}\"" \
                "kind = \"missing\"" \
                "detail = \"no contractiles dir\""
        return
    fi

    local missing_verbs=() drift_verbs=() present=()
    local verb
    for verb in "${CANONICAL_VERBS[@]}"; do
        local cdir="${repo}/.machine_readable/contractiles/${verb}"
        local capvfile="${cdir}/${verb^}file.a2ml"
        # Accept the canonical filename plus a few historical variants.
        if [[ -f "${capvfile}" \
            || -f "${cdir}/Intentfile.a2ml" \
            || -f "${cdir}/Trustfile.a2ml" ]]; then
            present+=("${verb}")
        else
            missing_verbs+=("${verb}")
        fi
    done

    # Legacy/drift verbs.
    for verb in "${LEGACY_DRIFT_VERBS[@]}"; do
        if [[ -d "${repo}/.machine_readable/contractiles/${verb}" ]]; then
            drift_verbs+=("${verb}")
        fi
    done

    # K9 location: SVC layer (canonical) vs nested in contractiles/ (drift).
    local k9_state="missing"
    if [[ -d "${repo}/.machine_readable/svc/k9" ]]; then
        k9_state="canonical"
    elif [[ -d "${repo}/.machine_readable/contractiles/k9" ]]; then
        k9_state="drift"
        drift_verbs+=("k9-in-contractiles")
    elif grep -qE "K9-SVC|coordination\.k9" \
            "${repo}/.github/workflows/"*.yml 2>/dev/null; then
        k9_state="workflow-only"
    fi

    # Accessibility hooks.
    local a11y_impl="no"
    if [[ -d "${repo}/server/lib/burble/accessibility" \
       || -d "${repo}/lib/accessibility" \
       || -f "${repo}/.machine_readable/contractiles/adjust/Adjustfile.a2ml" ]]; then
        a11y_impl="yes"
    fi

    local a11y_doc="no"
    if [[ -f "${repo}/docs/accessibility/README.adoc" ]] \
       || grep -qi "accessibility" "${repo}/README.adoc" 2>/dev/null; then
        a11y_doc="yes"
    fi

    # Classify.
    local status="ok"
    if (( ${#missing_verbs[@]} > 0 )); then status="missing"; fi
    if (( ${#drift_verbs[@]} > 0 )) && [[ "${status}" == "ok" ]]; then status="drift"; fi

    case "${status}" in
        ok)      (( C_OK++ ))      || true; gs::info  "${name}: ok (k9=${k9_state}, a11y=${a11y_impl}/${a11y_doc})" ;;
        drift)   (( C_DRIFT++ ))   || true; gs::warn  "${name}: drift — ${drift_verbs[*]}" ;;
        missing) (( C_MISSING++ )) || true; gs::warn  "${name}: missing verbs — ${missing_verbs[*]}" ;;
    esac

    if [[ -n "${REPORT_FILE}" ]]; then
        gs::report_add "${REPORT_FILE}" \
            "repo = \"${name}\"" \
            "kind = \"${status}\"" \
            "present = \"${present[*]:-}\"" \
            "missing = \"${missing_verbs[*]:-}\"" \
            "drift = \"${drift_verbs[*]:-}\"" \
            "k9 = \"${k9_state}\"" \
            "a11y_impl = \"${a11y_impl}\"" \
            "a11y_doc = \"${a11y_doc}\""
    fi
}

# -----------------------------------------------------------------------------
# Main.
# -----------------------------------------------------------------------------

gs::banner "Hyperpolymath Contractile Audit"

if (( OPT_KEY_ONLY )); then
    for r in "${KEY_REPOS[@]}"; do
        local_path="${GS_REPOS_DIR}/${r}"
        [[ -d "${local_path}/.git" ]] && audit_repo "${local_path}"
    done
else
    while IFS= read -r repo; do
        audit_repo "${repo}"
    done < <(gs::repos)
fi

gs::banner "Audit complete"
gs::info "total=${C_TOTAL}  ok=${C_OK}  drift=${C_DRIFT}  missing=${C_MISSING}"
[[ -n "${REPORT_FILE}" ]] && gs::info "report: ${REPORT_FILE}"

# Exit non-zero only when something is genuinely broken (missing).
(( C_MISSING > 0 )) && exit 2
exit 0
