#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# fix-unwrap-to-match.sh — convert bare .unwrap() Rust calls to a safer form.
#
# IMPORTANT: per memory feedback_unwrap_to_expect_antipattern,
# `.unwrap()` → `.expect("TODO")` is an ANTI-PATTERN — same panic, false debt
# marker. By default this script SKIPS that transformation and instead just
# REPORTS findings. Use --apply-expect to opt in to the legacy behaviour
# (e.g. when the user has already triaged each site and wants the marker).
#
# Self-healing/safe behaviour:
#   * Per-file snapshot saved before any edit; rollback path printed on
#     failure of subsequent type-check (run separately with `cargo check`).
#   * Skips test/bench files where .unwrap() is acceptable.
#   * Honours --dry-run.
#   * Bounded parallelism via -j N.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="fix-unwrap-to-match"
GS_HELP_TEXT="Usage: fix-unwrap-to-match.sh [--apply-expect] [--dry-run] <repo-path> [finding-json]

By default this script REPORTS bare .unwrap() calls in non-test Rust code
without modifying them (per the unwrap-to-expect anti-pattern memo).

Options:
      --apply-expect   Opt in to the .unwrap() -> .expect(\"TODO: handle\") rewrite
                       (NOT recommended; same panic, just adds a comment).
  -n, --dry-run        Show what would change.
  -y, --yes            Skip confirmation when --apply-expect is set.
  -j, --jobs N         Parallel workers for file iteration.
  -v, --verbose
  -q, --quiet
  -h, --help
"

gs::strict
gs::install_trap
gs::install_trap_summary

OPT_APPLY=0
REPO_PATH=""
FINDING_JSON=""

while (( $# > 0 )); do
    case "$1" in
        --apply-expect) OPT_APPLY=1 ;;
        -n|--dry-run)   GS_DRY_RUN=1 ;;
        -y|--yes)       GS_YES=1 ;;
        -j|--jobs)      GS_PARALLEL="${2:?}"; shift ;;
        -v|--verbose)   GS_LOG_LEVEL=debug ;;
        -q|--quiet)     GS_LOG_LEVEL=warn ;;
        -h|--help)      printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)
            if [[ -z "${REPO_PATH}" ]]; then REPO_PATH="$1"
            elif [[ -z "${FINDING_JSON}" ]]; then FINDING_JSON="$1"
            else gs::die "unexpected positional: $1"
            fi
            ;;
    esac
    shift
done

[[ -z "${REPO_PATH}" ]] && gs::die "repo path required (see --help)"
[[ -d "${REPO_PATH}" ]] || gs::die "repo path is not a directory: ${REPO_PATH}"

# Optional third-party-excludes plumbing kept for compat with older lib.
if [[ -f "${SCRIPT_DIR}/../lib/third-party-excludes.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../lib/third-party-excludes.sh"
fi
EXCLUDES=("${FIND_THIRD_PARTY_EXCLUDES[@]:-}")

is_test_or_bench() {
    local f="$1"
    case "$(basename -- "$f")" in
        *_test.rs|test_*.rs) return 0 ;;
    esac
    [[ "$f" == */tests/* || "$f" == */benches/* ]]
}

gs::banner "PanicPath audit: bare .unwrap() in non-test Rust"
gs::info "repo=${REPO_PATH}  apply=${OPT_APPLY}  dry-run=${GS_DRY_RUN}"
[[ -n "${FINDING_JSON}" ]] && gs::info "finding=${FINDING_JSON}"

if (( OPT_APPLY )) && ! gs::is_dry_run; then
    gs::warn "--apply-expect is enabled. This is an anti-pattern (panic preserved, fake debt marker)."
    gs::confirm "Proceed anyway?" || gs::die "aborted"
fi

REPORT_FILE="$(gs::report_path)"
gs::on_exit "echo 'report: ${REPORT_FILE}' >&2"

declare -i FILE_COUNT=0 SITE_COUNT=0 EDITED=0

# Iterate Rust files. Sequential — sed -i edits in place; parallel writes
# would race on the same file rarely, but keep it deterministic.
while IFS= read -r -d '' f; do
    is_test_or_bench "${f}" && continue
    grep -qP '\.unwrap\(\)' "${f}" 2>/dev/null || continue

    # Lines that are bare .unwrap() (not commented, not already .expect()).
    local_count=$(grep -P '\.unwrap\(\)' "${f}" 2>/dev/null \
        | grep -v '^\s*//' \
        | grep -v '\.expect(' \
        | wc -l || echo 0)
    (( local_count == 0 )) && continue

    rel="${f#${REPO_PATH}/}"
    (( FILE_COUNT++ )) || true
    SITE_COUNT=$(( SITE_COUNT + local_count ))

    gs::report_add "${REPORT_FILE}" \
        "file = \"${rel}\"" \
        "sites = ${local_count}"

    if (( OPT_APPLY )); then
        if gs::is_dry_run; then
            gs::info "DRY-RUN: would rewrite ${local_count} site(s) in ${rel}"
            continue
        fi
        snap="$(gs::snapshot "${f}")"
        gs::debug "snapshot: ${snap}"
        if sed -i -E '/^\s*\/\//!{ /\.expect\s*\(/!s/\.unwrap\(\)/\.expect("TODO: handle error")/g }' "${f}"; then
            (( EDITED++ )) || true
            gs::info "rewrote ${local_count} site(s) in ${rel}"
        else
            gs::error "sed failed; rolling back ${rel}"
            gs::rollback "${snap}" "${f}"
        fi
    else
        gs::warn "${rel}: ${local_count} bare .unwrap() (report-only; use --apply-expect to rewrite)"
    fi
done < <(find "${REPO_PATH}" -type f -name '*.rs' \
    -not -path '*/.git/*' -not -path '*/target/*' \
    "${EXCLUDES[@]}" -print0 2>/dev/null)

gs::banner "Done"
gs::info "files=${FILE_COUNT}  sites=${SITE_COUNT}  edited=${EDITED}"
gs::info "report: ${REPORT_FILE}"

if (( OPT_APPLY && EDITED > 0 )); then
    gs::warn "Run 'cargo check' on each affected crate before committing."
fi

# Report-only run: exit 0 even when sites were found (it's an inventory).
exit 0
