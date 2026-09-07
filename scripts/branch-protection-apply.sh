#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# branch-protection-apply.sh — repair an existing Base/Optimus-Branch baseline.
#
# Self-healing/safe behaviour:
#   * Validates gh auth and reports rate-limit headroom before any write.
#   * Preserves the entire existing policy, including other ruleset layers.
#   * Failed, malformed, incomplete or ambiguous reads never authorise writes.
#   * Does not provision missing baselines: those need a repository profile.
#   * Honours --dry-run; never writes when set.
#   * Emits an A2ML report of every repo's outcome at $GS_REPORT_DIR.
#   * Verifies writes by reading back; does not retry an ambiguous mutation.

set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "${SCRIPT_DIR}/lib/common.sh"

GS_SCRIPT_NAME="branch-protection-apply"
GS_HELP_TEXT="Usage: branch-protection-apply.sh [--dry-run] [--owner X] [--repo NAME] [--limit N] [--report] [--help]

Adds missing deletion, force-push, linear-history and signature protections to
an existing active 'Base' or 'Optimus-Branch' repository ruleset. Preserves its
other rules, checks, bypass actors and branch scope. Missing, inherited,
inactive or ambiguous baselines fail for profile-specific review.

Options:
  -n, --dry-run    Print what WOULD change; make no API writes.
      --owner X    GitHub org/user (default: hyperpolymath)
      --repo NAME  Limit the repair to one repository under --owner
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
OPT_REPO=""
OPT_REPORT=0

while (( $# > 0 )); do
    case "$1" in
        -n|--dry-run) GS_DRY_RUN=1 ;;
        -y|--yes)     GS_YES=1 ;;
        --owner)      OWNER="${2:?}"; shift ;;
        --repo)       OPT_REPO="${2:?}"; shift ;;
        --limit)      LIMIT="${2:?}"; shift ;;
        --report)     OPT_REPORT=1 ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        -h|--help)    printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)            gs::die "unknown flag: $1" ;;
    esac
    shift
done

[[ "${OWNER}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || gs::die "invalid owner"
[[ "${LIMIT}" =~ ^[1-9][0-9]{0,5}$ ]] || gs::die "limit must be between 1 and 999999"
[[ -z "${OPT_REPO}" || "${OPT_REPO}" =~ ^[A-Za-z0-9_.-]+$ ]] || gs::die "invalid repository name"
gs::assert_owner_allowed "${OWNER}"

REPORT_FILE=""
if (( OPT_REPORT )); then
    REPORT_FILE="$(gs::report_path "${GS_SCRIPT_NAME}")"
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
    gs::confirm "About to repair existing baseline rulesets for ${OWNER}/${OPT_REPO:-all repositories, limit ${LIMIT}}. Proceed?" \
        || gs::die "aborted by user"
fi

# -----------------------------------------------------------------------------
# Writable ruleset fields, with only missing baseline rule types added.
# -----------------------------------------------------------------------------

build_payload() {
    jq -ce '
      {name, target, enforcement, bypass_actors, conditions, rules}
      | reduce ["deletion", "non_fast_forward", "required_linear_history",
                "required_signatures"][] as $type (.;
          if any(.rules[]; .type == $type) then .
          else .rules += [{type: $type}] end)
    ' <<< "$1"
}

# -----------------------------------------------------------------------------
# Per-repo repair. Unknown is an error, never an empty policy.
# -----------------------------------------------------------------------------

apply_one() {
    local repo_name="$1" default_branch="$2" prefix="$3"
    local pages candidates existing_id existing_name url before payload fresh after backup
    if ! pages="$(gh api "repos/${OWNER}/${repo_name}/rulesets?per_page=100" --paginate --slurp)"; then
        gs::error "${prefix}: cannot list rulesets; no write"
        return 1
    fi
    if ! jq -e 'type == "array" and length > 0 and all(.[];
        type == "array" and all(.[];
          (.id | type == "number" and . > 0 and . == floor) and
          (.name | type == "string" and length > 0) and
          (.target == "branch" or .target == "tag" or .target == "push") and
          (.source_type | type == "string") and (.source | type == "string")))
        and ((add | map(.id) | unique | length) == (add | length))' \
        <<< "${pages}" >/dev/null; then
        gs::error "${prefix}: invalid ruleset inventory; no write"
        return 1
    fi
    candidates="$(jq -c '[.[][] | select(.target == "branch" and
        (.name == "Base" or .name == "Optimus-Branch"))]' <<< "${pages}")" || return 1
    if ! jq -e --arg repo "${OWNER}/${repo_name}" 'length == 1 and
        .[0].source_type == "Repository" and .[0].source == $repo' \
        <<< "${candidates}" >/dev/null; then
        gs::error "${prefix}: missing, inherited or ambiguous baseline; needs profile review; no write"
        return 1
    fi
    existing_id="$(jq -r '.[0].id' <<< "${candidates}")" || return 1
    existing_name="$(jq -r '.[0].name' <<< "${candidates}")" || return 1
    url="repos/${OWNER}/${repo_name}/rulesets/${existing_id}"
    if ! before="$(gh api "${url}")"; then
        gs::error "${prefix}: cannot read baseline #${existing_id}; no write"
        return 1
    fi
    if ! jq -e --argjson id "${existing_id}" --arg name "${existing_name}" \
        --arg repo "${OWNER}/${repo_name}" '
        type == "object" and .id == $id and .name == $name and
        .source_type == "Repository" and .source == $repo and
        .target == "branch" and .enforcement == "active" and
        (.bypass_actors | type == "array") and
        (.conditions | type == "object") and
        (.rules | type == "array" and all(.[];
          type == "object" and (.type | type == "string" and length > 0)))
      ' <<< "${before}" >/dev/null; then
        gs::error "${prefix}: invalid or inactive baseline; no write"
        return 1
    fi
    payload="$(build_payload "${before}")" || return 1
    if jq -e --argjson wanted "${payload}" \
        '{name,target,enforcement,bypass_actors,conditions,rules} == $wanted' \
        <<< "${before}" >/dev/null; then
        gs::info "${prefix}: baseline already has all four protections (${default_branch})"
        return 0
    fi
    if gs::is_dry_run; then
        gs::info "${prefix}: WOULD repair ${existing_name} #${existing_id} (${default_branch})"
        return 0
    fi
    backup="${GS_STATE_DIR}/ruleset-${OWNER}-${repo_name}-${existing_id}-$(date -u +%Y%m%dT%H%M%S%N).json"
    if ! printf '%s\n' "${before}" > "${backup}"; then
        gs::error "${prefix}: could not save pre-change ruleset; no write"
        return 1
    fi
    # Narrow the read/write race. GitHub does not offer a conditional ruleset PUT.
    if ! fresh="$(gh api "${url}")" ||
        ! jq -e --argjson before "${before}" '. == $before' <<< "${fresh}" >/dev/null; then
        gs::error "${prefix}: baseline changed or became unreadable; no write"
        return 1
    fi
    if ! gh api "${url}" --method PUT --input - <<< "${payload}" >/dev/null; then
        gs::error "${prefix}: update failed or outcome unknown; inspect #${existing_id} before retry; snapshot ${backup}"
        return 1
    fi
    if ! after="$(gh api "${url}")" ||
        ! jq -e --argjson id "${existing_id}" --argjson wanted "${payload}" \
            '.id == $id and ({name,target,enforcement,bypass_actors,conditions,rules} == $wanted)' \
            <<< "${after}" >/dev/null; then
        gs::error "${prefix}: update read-back failed; inspect #${existing_id}; snapshot ${backup}"
        return 1
    fi
    gs::info "${prefix}: verified repair of ${existing_name} #${existing_id}; snapshot ${backup}"
}

# -----------------------------------------------------------------------------
# Main loop.
# -----------------------------------------------------------------------------

gs::info "fetching repositories for ${OWNER}/${OPT_REPO:-all} (limit ${LIMIT})..."
if [[ -n "${OPT_REPO}" ]]; then
    if ! REPO="$(gh repo view "${OWNER}/${OPT_REPO}" --json name,nameWithOwner,defaultBranchRef,isArchived)"; then
        gs::die "could not read requested repository; no ruleset writes"
    fi
    if ! REPOS="$(jq -ce --arg repo "${OWNER}/${OPT_REPO}" \
        'if .nameWithOwner == $repo then [.] else error("repository identity mismatch") end' <<< "${REPO}")"; then
        gs::die "invalid requested repository; no ruleset writes"
    fi
else
    if ! REPOS="$(gh repo list "${OWNER}" --limit "$(( LIMIT + 1 ))" \
        --json name,nameWithOwner,defaultBranchRef,isArchived)"; then
        gs::die "could not enumerate repositories; no ruleset writes"
    fi
fi
if ! jq -e --arg owner "${OWNER}" --argjson limit "${LIMIT}" '
    type == "array" and length <= $limit and all(.[];
      (.name | type == "string" and test("^[A-Za-z0-9_.-]+$")) and
      .nameWithOwner == ($owner + "/" + .name) and
      (.isArchived | type == "boolean") and
      (.defaultBranchRef == null or (.defaultBranchRef.name | type == "string" and length > 0)))
    and ((map(.name) | unique | length) == length)' <<< "${REPOS}" >/dev/null; then
    gs::die "invalid or over-limit repository inventory; no ruleset writes (raise --limit if needed)"
fi
ROWS="$(jq -r '.[] | [.name, (.defaultBranchRef.name // "~NO_DEFAULT_BRANCH"), .isArchived] | @tsv' <<< "${REPOS}")"
REPO_ROWS=()
[[ -z "${ROWS}" ]] || mapfile -t REPO_ROWS <<< "${ROWS}"

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
    elif [[ "${default_branch}" == "~NO_DEFAULT_BRANCH" ]]; then
        gs::error "${prefix}: no default branch; no write"
        (( FAIL++ )) || true
        outcome="failed-no-default-branch"
    elif apply_one "${repo_name}" "${default_branch}" "${prefix}"; then
        (( OK++ )) || true
        outcome="verified-or-unchanged"
        if gs::is_dry_run; then outcome="dry-run-validated"; fi
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
gs::info "total=${REPO_COUNT}  validated=${OK}  dry_run=${GS_DRY_RUN}  archived=${SK_ARC}  failed=${FAIL}"
[[ -n "${REPORT_FILE}" ]] && gs::info "report: ${REPORT_FILE}"

(( FAIL > 0 )) && exit 1
exit 0
