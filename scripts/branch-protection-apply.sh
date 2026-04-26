#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# branch-protection-apply.sh — apply the canonical "Base" ruleset to all
# hyperpolymath GitHub repos via the rulesets API.
#
# Self-healing/safe behaviour:
#   * Always validates gh auth + rate-limit headroom before any write.
#   * Updates pre-existing rulesets in place rather than creating duplicates.
#   * Per-repo failure is captured + retried once (transient 5xx); the
#     overall run continues so one flake does not poison the batch.
#   * Honours --dry-run; never writes when set.
#   * Emits an A2ML report of every repo's outcome at $GS_REPORT_DIR.
#   * Exits non-zero only on persistent (post-retry) failures.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="branch-protection-apply"
GS_HELP_TEXT="Usage: branch-protection-apply.sh [--dry-run] [--owner X] [--limit N] [--report] [--help]

Applies the canonical 'Base' branch ruleset to every non-archived hyperpolymath
repo. Updates existing 'Base' rulesets in place (no duplicates).

Options:
  -n, --dry-run    Print what WOULD change; make no API writes.
      --owner X    GitHub org/user (default: hyperpolymath)
      --limit N    Max repos to fetch (default 600)
      --report     Write structured A2ML report to \$GS_REPORT_DIR
  -y, --yes        Skip the confirmation prompt
  -v, --verbose    Debug logging
  -q, --quiet      Warnings/errors only
  -h, --help       This message
"

gs::strict
gs::install_trap
gs::install_trap_summary
gs::lock branch-protection-apply

OWNER="hyperpolymath"
LIMIT=600
RULESET_NAME="Base"
OPT_REPORT=0

while (( $# > 0 )); do
    case "$1" in
        -n|--dry-run) GS_DRY_RUN=1 ;;
        -y|--yes)     GS_YES=1 ;;
        --owner)      OWNER="${2:?}"; shift ;;
        --limit)      LIMIT="${2:?}"; shift ;;
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

# -----------------------------------------------------------------------------
# Preflight.
# -----------------------------------------------------------------------------

gs::banner "Branch-protection ruleset rollout — ${OWNER}"
gs::need gh jq
gs::gh_check
gs::info "rate-limit remaining: $(gs::gh_remaining)"

if ! gs::is_dry_run; then
    gs::confirm "About to apply '${RULESET_NAME}' ruleset to up to ${LIMIT} ${OWNER} repos. Proceed?" \
        || gs::die "aborted by user"
fi

# -----------------------------------------------------------------------------
# Build payload (defined-once, parameterised by the repo's default branch).
# -----------------------------------------------------------------------------

build_payload() {
    cat <<'JSON'
{
  "name": "Base",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {"actor_id": 5,       "actor_type": "RepositoryRole", "bypass_mode": "always"},
    {"actor_id": 29110,   "actor_type": "Integration",    "bypass_mode": "always"},
    {"actor_id": 1143301, "actor_type": "Integration",    "bypass_mode": "always"},
    {"actor_id": 1236702, "actor_type": "Integration",    "bypass_mode": "always"}
  ],
  "conditions": {
    "ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "required_linear_history"},
    {"type": "required_signatures"},
    {"type": "required_deployments",
     "parameters": {"required_deployment_environments": []}},
    {"type": "required_status_checks",
     "parameters": {"strict_required_status_checks_policy": false,
                    "do_not_enforce_on_create": true,
                    "required_status_checks": []}},
    {"type": "code_scanning",
     "parameters": {"code_scanning_tools": [
        {"tool": "CodeQL",
         "alerts_threshold": "errors",
         "security_alerts_threshold": "high_or_higher"}]}}
  ]
}
JSON
}

# -----------------------------------------------------------------------------
# Per-repo apply with retry-on-transient.
# -----------------------------------------------------------------------------

apply_one() {
    local repo_name="$1" default_branch="$2" prefix="$3"
    local existing_id
    existing_id="$(gh api "repos/${OWNER}/${repo_name}/rulesets" \
        --jq ".[] | select(.name == \"${RULESET_NAME}\") | .id" 2>/dev/null || true)"

    local method url verb_msg
    if [[ -n "${existing_id}" ]]; then
        method=PUT
        url="repos/${OWNER}/${repo_name}/rulesets/${existing_id}"
        verb_msg="UPDATE existing #${existing_id}"
    else
        method=POST
        url="repos/${OWNER}/${repo_name}/rulesets"
        verb_msg="CREATE"
    fi

    if gs::is_dry_run; then
        gs::info "${prefix}: WOULD ${verb_msg} (${default_branch})"
        return 0
    fi

    local payload; payload="$(build_payload)"
    local attempt
    for attempt in 1 2; do
        if gh api "${url}" --method "${method}" --input - <<< "${payload}" >/dev/null 2>&1; then
            gs::info "${prefix}: ${verb_msg/WOULD /} ok (${default_branch})"
            return 0
        fi
        gs::warn "${prefix}: ${verb_msg} attempt ${attempt} failed; backing off..."
        sleep "$(( attempt * GS_GH_RETRY_BASE_S ))"
    done
    gs::error "${prefix}: ${verb_msg} failed after retry"
    return 1
}

# -----------------------------------------------------------------------------
# Main loop.
# -----------------------------------------------------------------------------

gs::info "fetching repos (limit ${LIMIT})..."
mapfile -t REPO_ROWS < <(gh repo list "${OWNER}" \
    --limit "${LIMIT}" \
    --json name,defaultBranchRef,isArchived \
    --jq '.[] | [.name, (.defaultBranchRef.name // "main"), .isArchived] | @tsv')

REPO_COUNT="${#REPO_ROWS[@]}"
gs::info "found ${REPO_COUNT} repos"

declare -i N=0 SK_ARC=0 OK=0 FAIL=0

for row in "${REPO_ROWS[@]}"; do
    (( N++ )) || true
    IFS=$'\t' read -r repo_name default_branch is_archived <<< "${row}"
    prefix="[${N}/${REPO_COUNT}] ${repo_name}"

    if [[ "${is_archived}" == "true" ]]; then
        gs::debug "${prefix}: skip (archived)"
        (( SK_ARC++ )) || true
        outcome="skipped-archived"
    elif apply_one "${repo_name}" "${default_branch}" "${prefix}"; then
        (( OK++ )) || true
        outcome="ok"
    else
        (( FAIL++ )) || true
        outcome="failed"
    fi

    if [[ -n "${REPORT_FILE}" ]]; then
        gs::report_add "${REPORT_FILE}" \
            "repo = \"${repo_name}\"" \
            "default_branch = \"${default_branch}\"" \
            "outcome = \"${outcome}\""
    fi
done

# -----------------------------------------------------------------------------
# Summary + exit code.
# -----------------------------------------------------------------------------

gs::banner "Summary"
gs::info "total=${REPO_COUNT}  applied=${OK}  archived=${SK_ARC}  failed=${FAIL}"
[[ -n "${REPORT_FILE}" ]] && gs::info "report: ${REPORT_FILE}"

(( FAIL > 0 )) && exit 1
exit 0
