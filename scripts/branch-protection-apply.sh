#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
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
# A FAILED SOURCE MUST NOT BE SURVIVABLE. This file runs under `set -uo pipefail`
# with NO `-e`, so a `.` that cannot find its library merely prints an error and
# CARRIES ON with every gs:: helper undefined. That is not a cosmetic failure:
#   `if gs::is_dry_run; then ...skip the write... fi`
# evaluates a missing function as rc=127, which is FALSY, so the dry-run branch
# is skipped and the script proceeds to PUT. The safety predicate fails OPEN.
#
# MEASURED 2026-09-15: running a COPY of this script from outside the repo (a
# backup in a scratch dir, to diff two versions) put SCRIPT_DIR somewhere with no
# lib/, and a `--dry-run` invocation wrote a live ruleset on hyperpolymath/
# gitbot-fleet. Every gs:: call printed "command not found" and the run still
# reported a summary, so the output looked like a completed dry run.
#
# So: die if the library cannot be loaded, and then assert that the specific
# predicates the write path depends on actually exist. A guard that cannot be
# found must be treated as a guard that said NO.
if ! . "${SCRIPT_DIR}/lib/common.sh"; then
    printf 'FATAL: cannot load %s/lib/common.sh -- refusing to run with no safety helpers\n' "${SCRIPT_DIR}" >&2
    exit 3
fi
for _fn in gs::is_dry_run gs::info gs::warn gs::error gs::die gs::confirm; do
    if ! declare -F "${_fn}" >/dev/null 2>&1; then
        printf 'FATAL: %s undefined after sourcing lib/common.sh -- refusing to run\n' "${_fn}" >&2
        exit 3
    fi
done

unset _fn

GS_SCRIPT_NAME="branch-protection-apply"
GS_HELP_TEXT="Usage: branch-protection-apply.sh [--dry-run] [--owner X] [--limit N] [--report] [--help]

Applies the canonical branch ruleset (--canon, default standards/config/rulesets/base.json)
to the target repos. Selects the existing ruleset by IDENTITY (active + target=branch +
conditions include exactly ["~DEFAULT_BRANCH"]), never by name, and updates it in
place; refuses any repo carrying two. Skips repos already canonical without writing.

Options:
  -n, --dry-run    Print what WOULD change; make no API writes.
      --owner X    GitHub org/user (default: hyperpolymath)
      --limit N    Max repos to fetch (default 600)
      --report     Write structured A2ML report to \$GS_REPORT_DIR
      --canon P    Canonical ruleset JSON (default: standards/config/rulesets/base.json)
      --rollback-dir D  Save each pre-write ruleset JSON into D before any PUT
      --retire-doubles F  File of owner/repo lines (R25). ONLY on those repos, a
                        double of one old-generation + one new-generation ruleset
                        is retired: Base replaces the OLD id and the NEW one is
                        DELETED. Both are snapshotted first; needs --rollback-dir.
                        Any repo not listed refuses on a double, exactly as before.
      --no-create  Migrate existing rulesets only; never CREATE one where none exists
      --repos-file F  Apply ONLY to the repos listed in F (field 1 = owner/repo, tab-sep);
                   without it the run targets EVERY repo in --owner
      --extras P   Overlay ruleset JSON (default: standards/config/rulesets/Optimus-Extras.json)
      --overlay R  Create/update the Optimus-Extras OVERLAY on repo R, then exit
      --overlay-off R  Delete the Optimus-Extras overlay from repo R, then exit
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
CANON_RULESET="${CANON_RULESET:-/home/hyperpolymath/developer/hyper-repos/standards/config/rulesets/base.json}"
ROLLBACK_DIR="${ROLLBACK_DIR:-}"
NO_CREATE="${NO_CREATE:-0}"
REPOS_FILE="${REPOS_FILE:-}"
OPT_REPORT=0
EXTRAS_RULESET="${EXTRAS_RULESET:-/home/hyperpolymath/developer/hyper-repos/standards/config/rulesets/Optimus-Extras.json}"
EXTRAS_NAME="Optimus-Extras"
OVERLAY_REPO=""
OVERLAY_MODE=""
RETIRE_DOUBLES_FILE="${RETIRE_DOUBLES_FILE:-}"
# R25 generation boundary. MEASURED on the 7 authorised repos, 2026-09-15 -- and
# the first value tried here (23,000,000, taken from the plan's prose "new
# generation (id >= 23M)") was WRONG and would have refused all seven. The real
# extremes on that population are:
#     highest OLD id   18875273  (self-destructing-git-garbage / marches era)
#     lowest  NEW id   22941164  (marches, producer-minted)
# a gap of ~4.07M, so 20,000,000 sits mid-gap and is not delicate. It remains a
# magic number tied to ONE measurement of ONE named population, and it is only a
# SECONDARY gate: authorisation to delete comes from --retire-doubles, never from
# this number. Re-measure before pointing --retire-doubles at any other repos.
NEWGEN_MIN="${NEWGEN_MIN:-20000000}"

while (( $# > 0 )); do
    case "$1" in
        -n|--dry-run) GS_DRY_RUN=1 ;;
        -y|--yes)     GS_YES=1 ;;
        --owner)      OWNER="${2:?}"; shift ;;
        --limit)      LIMIT="${2:?}"; shift ;;
        --report)     OPT_REPORT=1 ;;
        --canon)      CANON_RULESET="${2:?}"; shift ;;
        --rollback-dir) ROLLBACK_DIR="${2:?}"; shift ;;
        --retire-doubles) RETIRE_DOUBLES_FILE="${2:?}"; shift ;;
        --no-create)  NO_CREATE=1 ;;
        --repos-file) REPOS_FILE="${2:?}"; shift ;;
        --extras)     EXTRAS_RULESET="${2:?}"; shift ;;
        --overlay)      OVERLAY_REPO="${2:?}"; OVERLAY_MODE=on;  shift ;;
        --overlay-off)  OVERLAY_REPO="${2:?}"; OVERLAY_MODE=off; shift ;;
        -v|--verbose) GS_LOG_LEVEL=debug ;;
        -q|--quiet)   GS_LOG_LEVEL=warn ;;
        -h|--help)    printf '%s\n' "${GS_HELP_TEXT}"; exit 0 ;;
        *)            gs::die "unknown flag: $1" ;;
    esac
    shift
done

# R25: an unreadable allow-list must ABORT, not silently disable retiring. If it
# were merely skipped, every listed repo would refuse as an ordinary double and
# the run would look like "nothing to retire" rather than "I could not look".
if [[ -n "${RETIRE_DOUBLES_FILE}" ]]; then
    [[ -r "${RETIRE_DOUBLES_FILE}" ]] \
        || gs::die "--retire-doubles file not readable: ${RETIRE_DOUBLES_FILE}"
    [[ -n "${ROLLBACK_DIR}" ]] \
        || gs::die "--retire-doubles requires --rollback-dir: retiring DELETES a ruleset and both sides must be snapshotted first"
    gs::info "retire-doubles authorised for $(/usr/bin/grep -cE '^[^#[:space:]]+/[^#[:space:]]+$' "${RETIRE_DOUBLES_FILE}" || true) repo(s) from ${RETIRE_DOUBLES_FILE} (newgen boundary ${NEWGEN_MIN})"
fi


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
[[ -r "${CANON_RULESET}" ]] || gs::die "canonical ruleset not readable: ${CANON_RULESET}"
jq -e '.rules | map(.type) | index("pull_request")' "${CANON_RULESET}" >/dev/null \
    || gs::die "canon ${CANON_RULESET} has no pull_request rule -- refusing to strip PR enforcement"
gs::info "canon: ${CANON_RULESET} ($(jq -r '[.rules[].type] | join(",")' "${CANON_RULESET}"))"
gs::gh_check
gs::info "rate-limit remaining: $(gs::gh_remaining)"

# -----------------------------------------------------------------------------
# LAYER DISJOINTNESS — Base and Optimus-Extras must not overlap.
# -----------------------------------------------------------------------------
# Owner ruling R4: "make the base as tight as possible, and layer the extras
# that optimus adds on top, WITH NO DUPLICATION OF BASE. this allows me to turn
# that on or off." A rule present in BOTH layers cannot be turned off by
# removing the overlay -- Base still enforces it -- so the switch would lie.
# Worse, it would lie SILENTLY: removing the overlay returns success and the
# rule stays on. Fail loudly at load time instead of shipping a dishonest switch.
#
# Checked whenever the extras file exists, in EVERY mode -- not only in overlay
# mode -- because a base.json amended to absorb an extras rule breaks the switch
# just as thoroughly as an extras file that duplicates base, and the main sweep
# is what would write that base.
if [[ -r "${EXTRAS_RULESET}" ]]; then
    jq -e 'type == "object" and (.rules | type == "array")' "${EXTRAS_RULESET}" >/dev/null 2>&1 \
        || gs::die "extras ${EXTRAS_RULESET} is not a ruleset object with a .rules array"
    overlap="$(jq -rn \
        --slurpfile b "${CANON_RULESET}" --slurpfile x "${EXTRAS_RULESET}" \
        '[ $b[0].rules[].type ] as $bt
         | [ $x[0].rules[].type ] as $xt
         | [ $xt[] | select( . as $t | $bt | index($t) ) ] | unique | join(", ")')"
    if [[ -n "${overlap}" ]]; then
        gs::die "LAYER OVERLAP -- these rule types appear in BOTH ${CANON_RULESET##*/} and ${EXTRAS_RULESET##*/}: ${overlap}. The overlay switch cannot turn them off, so it would lie. Remove them from the overlay (Base is the floor) and re-run."
    fi
    gs::info "layers disjoint: Base [$(jq -r '[.rules[].type]|join(",")' "${CANON_RULESET}")] / Extras [$(jq -r '[.rules[].type]|join(",")' "${EXTRAS_RULESET}")]"
else
    gs::debug "no extras file at ${EXTRAS_RULESET} (disjointness check skipped)"
fi

# -----------------------------------------------------------------------------
# OVERLAY MODE — one repo, then exit (R4's on/off switch, R6's name).
# -----------------------------------------------------------------------------
# Deliberately a SEPARATE mode from the sweep rather than a per-repo column in
# the targets file. The overlay is opt-in per repo and its rules are the
# estate's own UNSAT_RULES set minus merge_queue -- rules measured here as
# unsatisfiable. A flag that can only be aimed at ONE repo at a time cannot be
# mass-applied by accident, which for this particular set is the whole point.
if [[ -n "${OVERLAY_MODE}" ]]; then
    ov_owner="${OWNER}"; ov_repo="${OVERLAY_REPO}"
    [[ "${OVERLAY_REPO}" == */* ]] && { ov_owner="${OVERLAY_REPO%%/*}"; ov_repo="${OVERLAY_REPO##*/}"; }
    ov_prefix="${ov_owner}/${ov_repo}"

    # Find any existing overlay BY NAME on the default branch. Two-step, because
    # the rulesets LIST endpoint omits .rules/.conditions/.bypass_actors
    # entirely -- filtering the list on shape matches NOTHING (measured: 0 of
    # 178). Name is the only field the list actually carries.
    ov_id="$(gh api "repos/${ov_prefix}/rulesets" --paginate \
               --jq ".[] | select(.name == \"${EXTRAS_NAME}\") | .id" 2>/dev/null | head -1 || true)"
    # THIRD occurrence of the same trap: `gh api` PRINTS THE RESPONSE BODY on a
    # 404, and `--jq` does not filter an error body, so a missing repo yields the
    # literal JSON {"message":"Not Found",...} as the "id". Caught in test, where
    # it produced `would UPDATE #{"message":"Not Found"...}` -- i.e. a PUT aimed at
    # a garbage URL. An id is DIGITS or it is not an id.
    [[ "${ov_id}" =~ ^[0-9]+$ ]] || ov_id=""

    gs::is_dry_run || gs::confirm "About to turn the ${EXTRAS_NAME} overlay ${OVERLAY_MODE^^} on ${ov_prefix}. Proceed?" || gs::die "aborted by user"

    if [[ "${OVERLAY_MODE}" == "off" ]]; then
        if [[ -z "${ov_id}" ]]; then
            gs::info "${ov_prefix}: no ${EXTRAS_NAME} overlay present -- nothing to remove"
            exit 0
        fi
        if [[ -n "${ROLLBACK_DIR}" ]]; then
            mkdir -p "${ROLLBACK_DIR}"
            gh api "repos/${ov_prefix}/rulesets/${ov_id}" \
                > "${ROLLBACK_DIR}/${ov_owner}-${ov_repo}-${ov_id}.json" 2>/dev/null \
                || gs::die "${ov_prefix}: could not snapshot overlay #${ov_id} before delete -- refusing"
            gs::info "${ov_prefix}: snapshot saved for overlay #${ov_id}"
        else
            gs::warn "${ov_prefix}: no --rollback-dir; deleting overlay #${ov_id} WITHOUT a snapshot"
        fi
        if gs::is_dry_run; then
            gs::info "DRY-RUN: would DELETE ${EXTRAS_NAME} #${ov_id} on ${ov_prefix}"
        else
            gh api -X DELETE "repos/${ov_prefix}/rulesets/${ov_id}" >/dev/null \
                || gs::die "${ov_prefix}: DELETE of overlay #${ov_id} failed"
            gs::info "${ov_prefix}: ${EXTRAS_NAME} #${ov_id} REMOVED"
        fi
        exit 0
    fi

    # --overlay (on)
    [[ -r "${EXTRAS_RULESET}" ]] || gs::die "extras ruleset not readable: ${EXTRAS_RULESET}"
    ov_payload="$(jq -c --arg n "${EXTRAS_NAME}" \
        '{name: $n, target: "branch", enforcement: "active",
          conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
          bypass_actors: (.bypass_actors // []),
          rules: .rules}' "${EXTRAS_RULESET}")"
    if [[ -n "${ov_id}" && -n "${ROLLBACK_DIR}" ]]; then
        mkdir -p "${ROLLBACK_DIR}"
        gh api "repos/${ov_prefix}/rulesets/${ov_id}" \
            > "${ROLLBACK_DIR}/${ov_owner}-${ov_repo}-${ov_id}.json" 2>/dev/null || true
    fi
    if gs::is_dry_run; then
        gs::info "DRY-RUN: would $( [[ -n "${ov_id}" ]] && echo "UPDATE #${ov_id}" || echo CREATE ) ${EXTRAS_NAME} on ${ov_prefix} ($(jq -r '[.rules[].type]|join(",")' "${EXTRAS_RULESET}"))"
        exit 0
    fi
    if [[ -n "${ov_id}" ]]; then
        printf '%s' "${ov_payload}" | gh api -X PUT "repos/${ov_prefix}/rulesets/${ov_id}" --input - >/dev/null \
            || gs::die "${ov_prefix}: PUT of overlay #${ov_id} failed"
        gs::info "${ov_prefix}: ${EXTRAS_NAME} #${ov_id} UPDATED"
    else
        printf '%s' "${ov_payload}" | gh api -X POST "repos/${ov_prefix}/rulesets" --input - >/dev/null \
            || gs::die "${ov_prefix}: POST of overlay failed"
        gs::info "${ov_prefix}: ${EXTRAS_NAME} CREATED"
    fi
    exit 0
fi

if ! gs::is_dry_run; then
    # ${REPOS_FILE:-...} expands to REPOS_FILE ITSELF when it is set, so the
    # prompt printed the path twice, concatenated. Compute the phrase first.
    target_desc=""
    if [[ -n "${REPOS_FILE}" ]]; then
        target_desc="the targets in ${REPOS_FILE}"
    else
        target_desc="up to ${LIMIT} ${OWNER} repos"
    fi
    gs::confirm "About to apply the canon at ${CANON_RULESET} to ${target_desc}. Proceed?" \
        || gs::die "aborted by user"
fi

# -----------------------------------------------------------------------------
# Build payload (defined-once, parameterised by the repo's default branch).
# -----------------------------------------------------------------------------

# Build the canonical ruleset payload with repository-specific checks and bypass actors.
# Arguments: required checks and bypass actors as JSON arrays; empty or null values become [].
# Omits the required-checks rule when no checks remain, writes JSON to stdout,
# and returns jq's status.
build_payload() {
    # $1 = the repo's EXISTING required_status_checks array (JSON)
    # $2 = the repo's EXISTING bypass_actors array (JSON)
    # Both are PRESERVED: this standardiser repairs the invariant baseline (the
    # rules) without clobbering per-repo status checks or bypass configuration.
    #
    # The rule set itself is READ FROM THE CANON (standards/config/rulesets/base.json),
    # never hardcoded here. The previous inline payload had drifted from the canon
    # and OMITTED the "pull_request" rule entirely, so applying it stripped PR
    # enforcement from every repo it touched. Do not reintroduce an inline payload.
    #
    # TWO measured reasons the canon is NOT sent verbatim (both are hard 422s,
    # proven on hyperpolymath/tropical-types 2026-09-09):
    #
    #  1. bypass_actors. The canon lists integrations (15368 GitHub Actions among
    #     them) that are not installed on every target:
    #       "Actor GitHub Actions integration must be part of the ruleset source
    #        or owner organization"
    #     Rewriting bypass actors is also a security-relevant change that the
    #     rollout was never asked to make, so the repo's own list is preserved.
    #
    #  2. required_status_checks. The canon carries an explicitly EMPTY list, and
    #     GitHub refuses it outright:
    #       "Invalid parameter required_status_checks: Expected at least 1
    #        elements, got 0"
    #     An empty rule would be a fake gate in any case, so when there is
    #     nothing to require the rule is DROPPED and the repo reported UNGATED
    #     -- which is what the rollout spec asked for.
    local existing_checks="${1:-[]}" existing_bypass="${2:-[]}"
    [[ -z "${existing_checks}" || "${existing_checks}" == "null" ]] && existing_checks='[]'
    [[ -z "${existing_bypass}" || "${existing_bypass}" == "null" ]] && existing_bypass='[]'

    jq -n \
        --slurpfile canon "${CANON_RULESET}" \
        --argjson checks "${existing_checks}" \
        --argjson bypass "${existing_bypass}" '
        $canon[0]
        | .bypass_actors = $bypass
        # keep every canonical rule; only splice the preserved contexts into
        # required_status_checks. Rules absent from the canon stay absent.
        | .rules = ( .rules
            | map( if .type == "required_status_checks"
                   then .parameters.required_status_checks = $checks
                   else . end )
            | map( select( .type != "required_status_checks"
                           or ( $checks | length ) > 0 ) )
          )
    '
}

# -----------------------------------------------------------------------------
# Per-repo apply with retry-on-transient.
# -----------------------------------------------------------------------------

# Distinguishes the four ways apply_one can succeed. "applied" conflated a real
# write with a no-op, so a 120-repo run would report applied=120 having changed
# nothing. Set at EVERY return-0 site.
LAST_OUTCOME=""
declare -i UNGATED=0
declare -i UNGATED_CONTEXT=0
declare -i CONDITIONAL_CONTEXT=0
declare -i WITNESS_UNAVAILABLE=0
declare -i MERGE_METHOD_REFUSED=0
declare -i MERGE_METHOD_UNREADABLE=0
declare -i REFUSED_NO_ROLLBACK=0
declare -i REFUSED_WITNESS=0
declare -i RETIRED_DOUBLES=0
declare -i RETIRE_REFUSED=0
# -----------------------------------------------------------------------------
# CONTEXT-WITNESS GATE
# -----------------------------------------------------------------------------
# A required status check that NEVER REPORTS blocks a PR permanently, at
# "Expected -- waiting for status", with ZERO red checks to point at. It is
# indistinguishable from a red at a glance, and it is the single defect this
# rollout must not reproduce or carry forward.
#
# MEASURED 2026-09-14, three repos, same shape every time:
#   hypatia         3 CodeQL contexts required, never reported across #775-#779;
#                   PRs #781/#782 were 14/14 pass and still BLOCKED.
#   proof-burrower  #76 requires 12, 42 check runs reported, 3 never:
#                   "Burrower proof safety", "rust-ci / llvm-cov line coverage",
#                   "Build Ddraig Pages artifact".
#   gitbot-fleet    #532 requires 11, 34 reported, 3 never:
#                   "CodeRabbit", "Dispatch path and outcome contracts",
#                   "GSBot build, tests and dependency security".
#
# This script PRESERVES each repo's existing required checks so the standardiser
# is additive. Without this filter it would faithfully carry every dead context
# forward into the new ruleset. Preservation is correct; preserving a context
# nobody emits is not.
#
# A context is kept only if it has ACTUALLY REPORTED on a recent head of this
# repo. The existence of a workflow file is NOT evidence -- hypatia ships
# codeql.yml and its contexts have never arrived.
#
# Two unrelated causes produce a never-reporting context and they need different
# fixes, so the report must say which (measured: 243 of 391 non-archived repos
# sit at allowed_actions=selected with patterns_allowed=[], which kills runs at
# startup with jobs.total_count==0 and NO check run emitted at all):
#   (a) the ruleset requires a context nobody emits;
#   (b) the repo's Actions settings prevent any context being emitted.
# Either way the context is not written; only the diagnosis differs.
#
# FAIL-SAFE: if the witness cannot be established (no head, API failure, or a
# completely empty check-run set) the checks are PRESERVED UNFILTERED and the
# repo is reported WITNESS-UNAVAILABLE. Dropping a real gate because we could
# not look is a far worse error than carrying a dead one, so SILENCE NEVER
# SUBTRACTS.
#
# Returns its result in the global WITNESS_OUT rather than on stdout: called in
# a command substitution the whole body would run in a SUBSHELL, and every
# counter it incremented -- UNGATED_CONTEXT, WITNESS_UNAVAILABLE, and common.sh's
# own GS_WARN_COUNT -- would be discarded at the closing paren, so the run
# summary would report 0 drops however many it made.
WITNESS_OUT='[]'
WITNESS_PROVENANCE=''
# Keep only required checks reported on sampled default-branch heads.
# Arguments: owner, repository, checks JSON, log prefix, and default branch.
# Stores results in WITNESS_OUT and WITNESS_PROVENANCE. If no candidate evidence
# can be read or the observed set is empty, preserves the input checks and returns success.
witness_filter_checks() {
    local owner="$1" repo_name="$2" checks_json="$3" prefix="$4" default_branch="${5:-}"
    local sha heads cr st union kept dropped n_req n_kept map n_heads n_bad cond cond_kept n_check_run_heads
    local cr_readable st_readable
    WITNESS_OUT="${checks_json}"
    WITNESS_PROVENANCE=''

    n_req="$(printf '%s' "${checks_json}" | jq 'length' 2>/dev/null || echo 0)"
    [[ "${n_req}" =~ ^[0-9]+$ ]] || n_req=0
    (( n_req == 0 )) && return 0

    # -- R20: PATH-CONDITIONAL CONTEXTS (owner ruling, 2026-09-15) ----------
    # A required context whose NAME IS A FILE PATH is path-conditional BY
    # CONSTRUCTION: it is emitted by a GitHub App that validates that one
    # config file, and it reports ONLY on commits that touch that path.
    #
    # MEASURED on hyperpolymath/standards#789: `.github/dependabot.yml` is a
    # required context on ruleset 23359343. The dependabot App had genuinely
    # reported it on recent heads, so it PASSES the witness gate below -- and
    # then blocks every PR that does not edit that file, forever, with ZERO
    # red checks. The witness gate asks "has this ever reported?"; its consumer
    # needs "will this report on an ARBITRARY PR?". For a conditional check
    # those answers differ permanently. (14th instance of that trap family.)
    #
    # So this runs BEFORE head selection, not after the witness union. The drop
    # is derived from the NAME, never from an observation, which means it also
    # holds on all four fail-safe paths below -- SILENCE NEVER SUBTRACTS still
    # governs witnessed contexts, but silence must not RESURRECT a conditional
    # one either.
    #
    # Predicate, deliberately two-limbed:
    #   (1) begins ".github/"                                  -- App config files
    #   (2) contains "/" AND ends .yml/.yaml/.json/.toml        -- any path-shaped name
    # Limb 2 needs the extension clause or it misfires: real witnessed contexts
    # in this estate are "governance / Code quality + docs", "SonarCloud Code
    # Analysis", "CodeQL", "CodeRabbit", "Registry + topology in sync", "Repo
    # self-tests" -- SPACED separators, title case, no file extension. The " / "
    # in "governance / Code quality + docs" is a job-name separator and carries
    # no extension, so limb 2 leaves it alone.
    cond="$(jq -rn --argjson c "${checks_json}" \
        '[ $c[] | .context | select( test("^\\.github/") or (test("/") and test("\\.(ya?ml|json|toml)$"; "i")) ) ] | join(", ")' \
        2>/dev/null || true)"
    if [[ -n "${cond}" ]]; then
        cond_kept="$(jq -cn --argjson c "${checks_json}" \
            '[ $c[] | select( .context | ( test("^\\.github/") or (test("/") and test("\\.(ya?ml|json|toml)$"; "i")) ) | not ) ]' \
            2>/dev/null || true)"
        # Same discipline as everywhere else in this file: a non-empty string is
        # not evidence of success. If the filter did not produce an array, keep
        # the unfiltered set rather than writing whatever jq printed.
        if printf '%s' "${cond_kept}" | jq -e 'type == "array"' >/dev/null 2>&1; then
            gs::warn "${prefix}: CONDITIONAL-CONTEXT -- dropping ${cond} (file-path-shaped name: App-emitted config validator, reports only on commits touching that path, so it blocks every other PR with zero red checks)"
            (( CONDITIONAL_CONTEXT++ )) || true
            checks_json="${cond_kept}"
            WITNESS_OUT="${checks_json}"
            n_req="$(printf '%s' "${checks_json}" | jq 'length' 2>/dev/null || echo 0)"
            [[ "${n_req}" =~ ^[0-9]+$ ]] || n_req=0
            # Dropping may have emptied the set. The caller turns [] into the
            # UNGATED branch and omits the rule entirely, which is correct: an
            # empty required_status_checks is a fake gate and GitHub 422s it.
            (( n_req == 0 )) && return 0
        fi
    fi

    # -- HEAD SELECTION ------------------------------------------------------
    # MEASURED 2026-09-14 on gitbot-fleet: ONE head is not a sample. At
    # 20f71d68 CodeQL + "governance / Code quality + docs" reported and
    # CodeRabbit did not; at 63f0868d the exact complement reported. A single
    # head reflects that PR's path/actor filters (Dependabot especially), not
    # the repo's gate inventory -- so sample several and UNION.
    #
    # Scoped to --base "${default_branch}": the ruleset being written governs
    # the DEFAULT branch, and an unscoped `gh pr list` handed this gate a PR
    # targeting a feature branch, which that ruleset does not govern at all.
    #
    # MERGED heads come first and are the strongest witness available: a merged
    # PR proves the ruleset was actually SATISFIED at that sha.
    heads=''
    if [[ -n "${default_branch}" ]]; then
        heads="$(gh pr list -R "${owner}/${repo_name}" --state merged --base "${default_branch}" \
                   --limit 5 --json headRefOid --jq '.[].headRefOid' 2>/dev/null || true)"
        heads="${heads}"$'\n'"$(gh pr list -R "${owner}/${repo_name}" --state open --base "${default_branch}" \
                   --limit 5 --json headRefOid --jq '.[].headRefOid' 2>/dev/null || true)"
    fi
    heads="${heads}"$'\n'"$(gh api "repos/${owner}/${repo_name}/commits?sha=${default_branch:-HEAD}&per_page=1" \
                 --jq '.[0].sha // empty' 2>/dev/null || true)"
    # Drop blanks, drop anything that is not a sha (gh api prints the 404 BODY),
    # and de-duplicate while PRESERVING order so merged heads stay first.
    heads="$(printf '%s\n' "${heads}" | grep -oE '^[0-9a-f]{7,40}$' | awk '!seen[$0]++' || true)"

    if [[ -z "${heads}" ]]; then
        gs::warn "${prefix}: WITNESS-UNAVAILABLE (no head to observe) -- preserving all ${n_req} checks unfiltered"
        (( WITNESS_UNAVAILABLE++ )) || true
        return 0
    fi

    # -- OBSERVATION ---------------------------------------------------------
    # A required context is satisfied by a check RUN *or* a legacy commit
    # STATUS, and the two APIs do not overlap. MEASURED on gitbot-fleet
    # @20f71d68: 34 check-runs, and `CodeRabbit` present ONLY in
    # /commits/{sha}/status. Reading just the Checks API would have stripped
    # CodeRabbit from the canon on every repo that requires it -- the gate
    # silently rewriting policy. `statusCheckRollup` is the union of both,
    # which is why its jq needs `.name // .context`. UNION, never one endpoint.
    map='{}'
    n_heads=0
    n_bad=0
    n_check_run_heads=0
    while IFS= read -r sha; do
        [[ -n "${sha}" ]] || continue
        cr="$(gh api "repos/${owner}/${repo_name}/commits/${sha}/check-runs" --paginate \
                --jq '[.check_runs[].name]' 2>/dev/null || true)"
        # `gh api` prints the response BODY on an error, so a non-empty string
        # is not evidence of success -- require a JSON array before trusting it.
        cr_readable=0
        if [[ -n "${cr}" ]] && printf '%s' "${cr}" | jq -e 'type == "array"' >/dev/null 2>&1; then
            # `--paginate` concatenates one array PER PAGE: `[...]\n[...]` is not
            # one array. Flatten before use; a flattening failure is unreadable.
            if cr="$(printf '%s' "${cr}" | jq -cs 'add // []' 2>/dev/null)"; then
                cr_readable=1
            else
                cr=''
            fi
        else
            cr=''
        fi
        st="$(gh api "repos/${owner}/${repo_name}/commits/${sha}/status" \
                --jq '[.statuses[].context]' 2>/dev/null || true)"
        st_readable=0
        if [[ -n "${st}" ]] && printf '%s' "${st}" | jq -e 'type == "array"' >/dev/null 2>&1; then
            st_readable=1
        else
            st=''
        fi
        # Legacy statuses can supplement check-run evidence, but cannot make a
        # missing or unreadable Checks API response look complete.
        if (( ! cr_readable || ! st_readable )); then
            (( n_bad++ )) || true
            continue
        fi
        (( n_heads++ )) || true
        if [[ "$(printf '%s' "${cr}" | jq 'length' 2>/dev/null || echo 0)" != "0" ]]; then
            (( n_check_run_heads++ )) || true
        fi
        union="$(jq -cn --argjson a "${cr:-[]}" --argjson b "${st:-[]}" '$a + $b | unique' 2>/dev/null || echo '[]')"
        # First witness wins, so provenance names the STRONGEST head (merged
        # before open before branch tip) that actually reported the context.
        #
        # Object "+" in jq is RIGHT-biased, so (new + $m) keeps whatever $m
        # already holds for a duplicate key -- that IS first-witness-wins, in
        # one operator. Do NOT express it as
        #     with_entries( select( ($m | has(.key)) | not ) )
        # because inside that pipe "." is $m, so ".key" reads $m's own .key
        # (null) rather than the entry's key: the select matches NOTHING and
        # the map stays permanently empty, which reads downstream as
        # WITNESS-EMPTY on every repo. Measured: all filtering cases returned
        # unfiltered until this line was changed.
        map="$(jq -cn --argjson m "${map}" --argjson u "${union}" --arg h "${sha}" \
                 '( $u | map({key: ., value: $h}) | from_entries ) + $m' \
                 2>/dev/null || printf '%s' "${map}")"
    done <<< "${heads}"

    if (( n_heads == 0 )); then
        gs::warn "${prefix}: WITNESS-UNAVAILABLE (checks unreadable at all ${n_bad} candidate heads) -- preserving all ${n_req} checks unfiltered"
        (( WITNESS_UNAVAILABLE++ )) || true
        return 0
    fi
    # Statuses alone do not establish that checks can run. If none of the fully
    # readable heads reported a check run, this may be a settings-level startup
    # kill rather than evidence that every required gate is dead. Never subtract.
    if (( n_check_run_heads == 0 )); then
        gs::warn "${prefix}: WITNESS-EMPTY across ${n_heads} head(s) -- NO check runs reported; probable startup kill (check actions/permissions), preserving all ${n_req} checks unfiltered"
        (( WITNESS_UNAVAILABLE++ )) || true
        return 0
    fi

    kept="$(jq -cn --argjson c "${checks_json}" --argjson m "${map}" \
              '[ $c[] | select( .context as $x | $m | has($x) ) ]' 2>/dev/null || true)"
    printf '%s' "${kept}" | jq -e 'type == "array"' >/dev/null 2>&1 || {
        gs::warn "${prefix}: WITNESS-UNAVAILABLE (filter failed) -- preserving all ${n_req} checks unfiltered"
        (( WITNESS_UNAVAILABLE++ )) || true
        return 0
    }
    dropped="$(jq -rn --argjson c "${checks_json}" --argjson m "${map}" \
              '[ $c[] | select( .context as $x | ($m | has($x)) | not ) | .context ] | join(", ")' 2>/dev/null || true)"
    n_kept="$(printf '%s' "${kept}" | jq 'length')"
    # Provenance: R12 requires the repair issue to cite WHICH head witnessed
    # each surviving context, so a reader can re-observe the same evidence.
    WITNESS_PROVENANCE="$(jq -rn --argjson c "${checks_json}" --argjson m "${map}" \
              '[ $c[] | .context as $x | select( $m | has($x) ) | "\($x)@\($m[$x][0:8])" ] | join(", ")' 2>/dev/null || true)"

    if [[ -n "${dropped}" ]]; then
        gs::warn "${prefix}: UNGATED-CONTEXT -- dropping ${dropped} (required but never reported across ${n_heads} default-branch head(s), check-runs AND statuses; ${n_kept}/${n_req} witnessed)"
        (( UNGATED_CONTEXT++ )) || true
    fi
    if [[ -n "${WITNESS_PROVENANCE}" ]]; then
        gs::info "${prefix}: witnessed ${n_kept}/${n_req} over ${n_heads} head(s) -- ${WITNESS_PROVENANCE}"
    fi
    WITNESS_OUT="${kept}"
    return 0
}

# Reconcile one repository's active default-branch ruleset with the canon.
# Arguments: repository, default branch, log prefix, optional owner override,
# and optional pinned ruleset ID.
# May save a rollback snapshot and create or update the ruleset; honours dry-run
# and no-create modes. Sets LAST_OUTCOME on success, returns non-zero for a refused
# or failed API operation, and exits if rollback storage fails.
apply_one() {
    local repo_name="$1" default_branch="$2" prefix="$3"
    # Owner is PER ROW. The estate spans two orgs (102 hyperpolymath + 18
    # metadatastician in the 2026-09-09 target set); a single global OWNER
    # silently skipped every metadatastician target. This local shadows it.
    local OWNER="${4:-${OWNER}}"
    LAST_OUTCOME=""

    # ---- MERGE-METHOD PREFLIGHT -------------------------------------------
    # The canon pins `allowed_merge_methods` (today: ["squash"]). A ruleset can
    # only NARROW what the repo SETTINGS already permit -- it cannot re-enable a
    # method the repo has switched off. So if the repo has `allow_squash_merge:
    # false` and the ruleset says squash-only, the intersection is EMPTY and the
    # repo has NO legal merge method at all: permanently unmergeable, the same
    # trap family as the zero-bypass canon this rollout exists to remove.
    #
    # REFUSE rather than silently widening the method set. Writing a wider set
    # than canon would make this repo quietly non-canonical; flipping the repo
    # setting would be an unattended settings change, which is forbidden. The
    # right output is a NAME ON A LIST for the owner.
    #
    # Derived from the canon, not hardcoded to "squash", so amending base.json
    # cannot leave this check testing the wrong thing -- the recurring
    # "a guard asks a different question than its consumer" defect.
    local want_methods
    want_methods="$(jq -r '[.rules[]? | select(.type=="pull_request")
                            | .parameters.allowed_merge_methods // empty] | add // []
                           | join(" ")' "${CANON_RULESET}" 2>/dev/null || true)"
    if [[ -n "${want_methods}" ]]; then
        local repo_settings legal="" m setting
        local rc_settings=0
        repo_settings="$(gh api "repos/${OWNER}/${repo_name}" \
            --jq '{merge:.allow_merge_commit, squash:.allow_squash_merge, rebase:.allow_rebase_merge}' 2>/dev/null)" || rc_settings=$?
        # A 403/404 error BODY is itself valid JSON, and `jq '{squash:.allow_squash_merge}'`
        # over it yields a well-formed object of NULLs. `type == "object"` therefore PASSES on a
        # rate-limited read, every field compares unequal to "true", and the repo is reported
        # SQUASH-DISABLED when the truth is "could not look". Measured 2026-09-15: 22 consecutive
        # repos refused in 13s at the tail of a 120-repo run, all of them `allow_squash_merge: true`.
        # The guard must ask what its consumer needs -- "did this come from the repo?" -- so assert
        # the FIELDS are booleans, which an error body can never satisfy.
        if (( rc_settings == 0 )) && printf '%s' "${repo_settings}" \
             | jq -e '(.merge|type=="boolean") and (.squash|type=="boolean") and (.rebase|type=="boolean")' \
             >/dev/null 2>&1; then
            for m in ${want_methods}; do
                case "${m}" in
                    merge)  setting=merge  ;;
                    squash) setting=squash ;;
                    rebase) setting=rebase ;;
                    *)      continue      ;;
                esac
                if [[ "$(printf '%s' "${repo_settings}" | jq -r ".${setting}")" == "true" ]]; then
                    legal="${legal} ${m}"
                fi
            done
            if [[ -z "${legal// /}" ]]; then
                if [[ "${want_methods}" == "squash" ]]; then
                    gs::error "${prefix}: SQUASH-DISABLED -- canon requires squash-only but allow_squash_merge=false; writing it would leave NO legal merge method -- refusing"
                else
                    gs::error "${prefix}: MERGE-METHOD-IMPOSSIBLE -- canon allows [${want_methods}] but the repo enables none of them -- refusing"
                fi
                (( MERGE_METHOD_REFUSED++ )) || true
                return 1
            fi
        else
            # Could not read the settings: do not guess. Refusing here is the
            # fail-safe -- a write made blind is the one that cannot be undone
            # by re-running, because the repo may already be unmergeable.
            gs::error "${prefix}: MERGE-METHOD-UNREADABLE -- could not read repo merge settings (gh rc=${rc_settings}); this is NOT evidence a method is disabled -- refusing"
            (( MERGE_METHOD_UNREADABLE++ )) || true
            return 1
        fi
    fi
    # -----------------------------------------------------------------------
    # Identity is the TARGET, never the name (standards/config/README.adoc).
    # Live waves are variously named Base, Backup, Pages-fix, Optimus-Branch,
    # default-branch-protection. Selecting by name made this script POST a
    # SECOND active ruleset onto every repo whose ruleset was named anything
    # else -- leaving the old one in force and double-gating the repo. The
    # canon: exactly one active branch ruleset including exactly
    # ["~DEFAULT_BRANCH"]; zero means CREATE, two or more is a verifier failure.
    #
    # This MUST be two-step. The rulesets LIST endpoint returns a summary that
    # omits `conditions`, `rules` and `bypass_actors` entirely, so filtering the
    # list on .conditions matches NOTHING -- measured 0 of 178 live repos on
    # 2026-09-09 -- which silently turns every PUT into a POST and recreates the
    # exact duplicate-ruleset bug this selector exists to prevent. Only
    # GET .../rulesets/{id} carries the shape.
    local pin_id="${5:-}"
    local cand_ids id rs_json ids='' id_count existing_id existing_full=''
    # PINNED-ID MODE. The doubles (8 repos on 2026-09-09) legitimately run two
    # active ~DEFAULT_BRANCH rulesets: the Optimus-Branch wave AND a newer
    # purpose-built one. Refusing them wholesale is right by default -- but when
    # the owner rules that only the Optimus one is to be replaced, the identity
    # test cannot pick it out. Field 2 of the repos file names the id to write.
    # It still must be active, branch-targeted and exactly ~DEFAULT_BRANCH: a
    # pinned id is a tie-break among valid candidates, never a way past the test.
    if [[ -n "${pin_id}" ]]; then
        rs_json="$(gh api "repos/${OWNER}/${repo_name}/rulesets/${pin_id}" 2>/dev/null || true)"
        # `gh api` PRINTS THE RESPONSE BODY ON A 404, so a non-existent ruleset
        # yields a NON-EMPTY string and sails past an emptiness check. That is
        # why D11's 120 refusals all read "is not an active ~DEFAULT_BRANCH
        # branch ruleset" -- the true cause was "no such ruleset". Assert the
        # object actually IS a ruleset (it carries a numeric .id) before judging
        # its shape, and report a 404 as a 404.
        printf '%s' "${rs_json}" | jq -e 'type == "object" and (.id | type == "number")' >/dev/null 2>&1 \
            || { gs::error "${prefix}: pinned ruleset #${pin_id} does not exist on this repo ($(printf '%s' "${rs_json}" | jq -r '.message // "no response"' 2>/dev/null)) -- refusing"; return 1; }
        printf '%s' "${rs_json}" | jq -e '.enforcement == "active" and .target == "branch" and ((.conditions.ref_name.include // []) == ["~DEFAULT_BRANCH"])' >/dev/null 2>&1 \
            || { gs::error "${prefix}: pinned ruleset #${pin_id} is not an active ~DEFAULT_BRANCH branch ruleset -- refusing"; return 1; }
        ids="${pin_id}"$'\n'
        existing_full="${rs_json}"
        gs::info "${prefix}: pinned to ruleset #${pin_id} ($(printf '%s' "${rs_json}" | jq -r .name)) -- other active rulesets on this repo are left in force"
    else
        cand_ids="$(gh api "repos/${OWNER}/${repo_name}/rulesets" \
            --jq '.[] | select(.enforcement == "active" and .target == "branch") | .id' 2>/dev/null || true)"
        for id in ${cand_ids}; do
            rs_json="$(gh api "repos/${OWNER}/${repo_name}/rulesets/${id}" 2>/dev/null || true)"
            [[ -z "${rs_json}" ]] && continue
            if printf '%s' "${rs_json}" \
                | jq -e '(.conditions.ref_name.include // []) == ["~DEFAULT_BRANCH"]' >/dev/null 2>&1; then
                ids="${ids}${id}"$'\n'
                existing_full="${rs_json}"
            fi
        done
    fi

    id_count="$(printf '%s' "${ids}" | /usr/bin/grep -c . || true)"

    local retire_id=""
    if (( id_count > 1 )); then
        # R25 (owner ruling, 2026-09-15). On a NAMED list of repos, a double made
        # of one old-generation ruleset plus one NEW-generation producer ruleset
        # is retired: tight Base replaces the OLD id, and the producer's is
        # DELETED, so the repo ends with exactly one canonical ruleset.
        #
        # AUTHORISATION IS DATA, NOT A HEURISTIC. The repo must be named in
        # --retire-doubles or this refuses exactly as it always did. E1 still
        # protects the owner's HAND-BUILT second layers ("Proof stack safety",
        # "Publication and continuity verification"): those repos are simply
        # never on the list, so no predicate can mistake one for producer output.
        # The id-generation split below is a SECOND gate, never the authorisation.
        local old_ids="" new_ids="" i
        for i in ${ids}; do
            if (( i >= NEWGEN_MIN )); then new_ids="${new_ids}${i} "; else old_ids="${old_ids}${i} "; fi
        done
        if [[ -n "${RETIRE_DOUBLES_FILE}" ]] \
           && /usr/bin/grep -qixF "${OWNER}/${repo_name}" "${RETIRE_DOUBLES_FILE}" \
           && (( id_count == 2 )) \
           && [[ "$(printf '%s' "${old_ids}" | wc -w)" == "1" ]] \
           && [[ "$(printf '%s' "${new_ids}" | wc -w)" == "1" ]]; then
            local old_id="${old_ids// /}" new_id="${new_ids// /}" old_json new_json
            old_json="$(gh api "repos/${OWNER}/${repo_name}/rulesets/${old_id}" 2>/dev/null || true)"
            new_json="$(gh api "repos/${OWNER}/${repo_name}/rulesets/${new_id}" 2>/dev/null || true)"
            # An error BODY is itself valid JSON (trap 15), so assert a NUMERIC
            # .id -- never merely that the response parsed. A rate-limited read
            # must never be allowed to look like a verified pair.
            if ! printf '%s' "${old_json}" | jq -e '.id | type == "number"' >/dev/null 2>&1 \
               || ! printf '%s' "${new_json}" | jq -e '.id | type == "number"' >/dev/null 2>&1; then
                gs::error "${prefix}: RETIRE-UNREADABLE -- cannot re-read both rulesets (#${old_id}, #${new_id}); refusing to retire on an unverified pair"
                (( RETIRE_REFUSED++ )) || true
                return 1
            fi
            if [[ -z "${ROLLBACK_DIR}" ]]; then
                gs::error "${prefix}: RETIRE-NO-ROLLBACK -- retiring DELETES a ruleset and needs --rollback-dir; refusing to delete without a snapshot"
                (( RETIRE_REFUSED++ )) || true
                return 1
            fi
            mkdir -p "${ROLLBACK_DIR}" || gs::die "cannot create rollback dir ${ROLLBACK_DIR}"
            printf '%s\n' "${old_json}" > "${ROLLBACK_DIR}/${OWNER}-${repo_name}-${old_id}.json" \
                || gs::die "${prefix}: cannot snapshot #${old_id} -- refusing"
            printf '%s\n' "${new_json}" > "${ROLLBACK_DIR}/${OWNER}-${repo_name}-${new_id}-RETIRED.json" \
                || gs::die "${prefix}: cannot snapshot #${new_id} -- refusing"
            ids="${old_id}"
            existing_full="${old_json}"
            retire_id="${new_id}"
            id_count=1
            gs::warn "${prefix}: RETIRE-DOUBLE -- Base replaces old #${old_id}; producer ruleset #${new_id} ($(printf '%s' "${new_json}" | jq -r '.name // "?"')) will be DELETED once the Base write succeeds (both snapshotted)"
        else
            gs::error "${prefix}: ${id_count} active ~DEFAULT_BRANCH rulesets ($(printf '%s' "${ids}" | tr '\n' ' ')) -- refusing; the canon requires exactly one"
            return 1
        fi
    fi
    existing_id="$(printf '%s' "${ids}" | head -n1)"

    # Rollback BEFORE any write, from the object already fetched. Saved on dry
    # runs too -- it is a read, and having it costs nothing.
    if [[ -n "${existing_id}" && -n "${ROLLBACK_DIR}" ]]; then
        mkdir -p "${ROLLBACK_DIR}" || gs::die "cannot create rollback dir ${ROLLBACK_DIR}"
        printf '%s\n' "${existing_full}" \
            > "${ROLLBACK_DIR}/${OWNER}-${repo_name}-${existing_id}.json" \
            || gs::die "${prefix}: cannot write rollback -- refusing to proceed"
    fi

    local method url verb_msg
    if [[ -n "${existing_id}" ]]; then
        method=PUT
        url="repos/${OWNER}/${repo_name}/rulesets/${existing_id}"
        verb_msg="UPDATE existing #${existing_id}"
    else
        if (( NO_CREATE )); then
            gs::info "${prefix}: no active ~DEFAULT_BRANCH ruleset and --no-create is set -- skipping (creating one would ADD protection this repo never had)"
            LAST_OUTCOME="skipped-no-create"
            return 0
        fi
        method=POST
        url="repos/${OWNER}/${repo_name}/rulesets"
        verb_msg="CREATE"
    fi

    # Read the repo's own required status checks so the standardiser is additive
    # (repairs the baseline rules) rather than wiping per-repo gates on the PUT.
    # Taken from the by-id JSON fetched above: the LIST summary has no `rules`
    # key at all, so re-reading the list here would silently yield [] and wipe
    # every per-repo gate in the estate.
    local existing_checks='[]'
    if [[ -n "${existing_full}" ]]; then
        existing_checks="$(printf '%s' "${existing_full}" \
            | jq -c '([.rules[]? | select(.type=="required_status_checks") | .parameters.required_status_checks] | add) // []' 2>/dev/null || echo '[]')"
        [[ -z "${existing_checks}" || "${existing_checks}" == "null" ]] && existing_checks='[]'
    fi
    # Preserve the repo's own bypass actors (see build_payload note 1: sending
    # the canon's list 422s where those integrations are not installed).
    local existing_bypass='[]'
    if [[ -n "${existing_full}" ]]; then
        existing_bypass="$(printf '%s' "${existing_full}" \
            | jq -c '.bypass_actors // []' 2>/dev/null || echo '[]')"
        [[ -z "${existing_bypass}" || "${existing_bypass}" == "null" ]] && existing_bypass='[]'
    fi
    # Filter the preserved set to contexts the repo has ACTUALLY EMITTED. This
    # sits between "read what exists" and "decide whether the rule is empty", so
    # a repo whose every required context is dead falls through to the UNGATED
    # branch below and has the rule OMITTED -- not written empty (GitHub 422s an
    # empty required_status_checks anyway) and not written dead.
    # WITNESS_UNAVAILABLE is a CUMULATIVE counter across every repo in the run,
    # so it cannot answer "did the witness step fail for THIS repo?". Snapshot
    # it across the call to get a per-repo signal (R23, owner 2026-09-15).
    local witness_before="${WITNESS_UNAVAILABLE}"
    witness_filter_checks "${OWNER}" "${repo_name}" "${existing_checks}" "${prefix}" "${default_branch}"
    local repo_witness_failed=0
    (( WITNESS_UNAVAILABLE > witness_before )) && repo_witness_failed=1 || true
    existing_checks="${WITNESS_OUT}"
    [[ -z "${existing_checks}" || "${existing_checks}" == "null" ]] && existing_checks='[]'
    if [[ "${existing_checks}" == '[]' ]]; then
        gs::warn "${prefix}: UNGATED -- no required status checks to preserve; omitting the rule rather than writing an empty one"
        (( UNGATED++ )) || true
    fi
    local payload; payload="$(build_payload "${existing_checks}" "${existing_bypass}")"

    # Compare BEFORE writing. Without this the PUT fires unconditionally on
    # every run, so "run it twice, the second makes zero writes" could never
    # hold, and a 120-repo run killed part-way could not be resumed without
    # re-PUTting everything already done.
    #
    # The test is SUBSET, not equality: GitHub echoes back server-side defaults
    # we never send (measured: a `dismissal_restriction` object inside the
    # pull_request rule), and a live object also carries id/_links/source/
    # created_at/updated_at/current_user_can_bypass. Equality therefore NEVER
    # matches and the script rewrites the same repo forever. If everything we
    # would send is already present with the same value, the PUT is a no-op.
    # Arrays compare as sets of the same length, so rule/actor ordering -- which
    # GitHub does not preserve -- does not cause a spurious rewrite, while a
    # dropped or added element still does.
    if [[ -n "${existing_full}" ]]; then
        local is_same
        is_same="$(jq -n \
            --argjson payload "${payload}" \
            --argjson live "${existing_full}" '
            def sub($a; $b):
              if ($a|type) == "object" then
                ($b|type) == "object"
                  and ($a | keys_unsorted | all(. as $k | ($b|has($k)) and sub($a[$k]; $b[$k])))
              elif ($a|type) == "array" then
                ($b|type) == "array"
                  and ($a|length) == ($b|length)
                  and ($a | all(. as $e | $b | any(. as $c | sub($e; $c))))
              else $a == $b end;
            sub($payload; $live)' 2>/dev/null || echo 'error')"
        if [[ "${is_same}" == "true" ]]; then
            gs::info "${prefix}: already canonical (#${existing_id}) -- no write"
            LAST_OUTCOME="already-canonical"
            return 0
        fi
    fi

    # ---- R23 REFUSALS (owner 2026-09-15) ----------------------------------
    # Deliberately placed BEFORE the dry-run branch so a dry run reports the
    # SAME verdict a live run would. Reporting "would-write" for a repo that a
    # live run will refuse is the guard-mismatch trap this script exists to
    # avoid -- the census must predict the rollout, not flatter it.
    #
    # (1) No --rollback-dir, no write. S3 already mandates a pre-write snapshot
    #     per repo; this makes that rule mechanical rather than dependent on the
    #     operator remembering a flag. Ruleset writes ARE recoverable via the
    #     version-history endpoint, but recovery is not a substitute for a plan.
    if [[ -z "${ROLLBACK_DIR}" ]]; then
        gs::error "${prefix}: REFUSED-NO-ROLLBACK -- ${verb_msg} needs --rollback-dir; refusing to write without a pre-write snapshot"
        (( REFUSED_NO_ROLLBACK++ )) || true
        LAST_OUTCOME="refused-no-rollback"
        return 1
    fi
    # (2) Witness step failed for THIS repo => we could not measure it, so we do
    #     not write it. Previously WITNESS_UNAVAILABLE was a counter only and the
    #     repo was still written with its contexts preserved unfiltered. Accepted
    #     cost, chosen by the owner over the narrower arm: this refuses a slice of
    #     the 243/391 empty-allowlist startup-kill class, so each pass covers
    #     fewer repos. Safety over coverage.
    if (( repo_witness_failed )); then
        gs::error "${prefix}: REFUSED-WITNESS-UNAVAILABLE -- could not observe this repo's checks, so its required contexts are unverified; refusing to write an unmeasured ruleset"
        (( REFUSED_WITNESS++ )) || true
        LAST_OUTCOME="refused-witness-unavailable"
        return 1
    fi

    if gs::is_dry_run; then
        gs::info "${prefix}: WOULD ${verb_msg} (${default_branch})"
        [[ -n "${retire_id}" ]] && gs::info "${prefix}: WOULD RETIRE ruleset #${retire_id} -- deleted only AFTER the Base write succeeds; a dry run deletes nothing"
        LAST_OUTCOME="would-write"
        return 0
    fi
    local attempt api_err
    for attempt in 1 2; do
        # Capture stderr: swallowing it hid a hard 422 ("Expected at least 1
        # elements, got 0") behind a bare "attempt failed", which is why the
        # cause had to be reproduced by hand. Never discard the response body.
        if api_err="$(gh api "${url}" --method "${method}" --input - <<< "${payload}" 2>&1 >/dev/null)"; then
            gs::info "${prefix}: ${verb_msg/WOULD /} ok (${default_branch})"
            # R25: delete the producer ruleset ONLY now. WRITE-THEN-DELETE, never
            # the reverse -- deleting first and then failing the write would leave
            # the repo with NO default-branch protection at all, strictly worse
            # than the double we set out to fix. A failed delete leaves Base
            # written and the producer ruleset still additive: no worse than
            # before, so it is reported LOUDLY and never retried blindly.
            if [[ -n "${retire_id}" ]]; then
                local del_err
                if del_err="$(gh api "repos/${OWNER}/${repo_name}/rulesets/${retire_id}" --method DELETE 2>&1 >/dev/null)"; then
                    gs::info "${prefix}: RETIRED ruleset #${retire_id} (snapshot: ${ROLLBACK_DIR}/${OWNER}-${repo_name}-${retire_id}-RETIRED.json)"
                    (( RETIRED_DOUBLES++ )) || true
                else
                    gs::error "${prefix}: RETIRE-DELETE-FAILED #${retire_id}: ${del_err//$'\n'/ } -- Base IS written, but the producer ruleset is STILL ACTIVE and still additive on this repo"
                    (( RETIRE_REFUSED++ )) || true
                fi
            fi
            LAST_OUTCOME="written"
            return 0
        fi
        gs::warn "${prefix}: ${verb_msg} attempt ${attempt} failed: ${api_err//$'\n'/ }"
        sleep "$(( attempt * GS_GH_RETRY_BASE_S ))"
    done
    gs::error "${prefix}: ${verb_msg} failed after retry"
    return 1
}

# -----------------------------------------------------------------------------
# Main loop.
# -----------------------------------------------------------------------------

# Rows are owner<TAB>name<TAB>default_branch<TAB>archived. The owner is carried
# PER ROW because the target population spans two orgs; the old single-OWNER
# `gh repo list` form could not express that and would also have applied to
# EVERY repo in the org rather than the measured target set.
declare -a REPO_ROWS=()
if [[ -n "${REPOS_FILE}" ]]; then
    [[ -r "${REPOS_FILE}" ]] || gs::die "repos file not readable: ${REPOS_FILE}"
    gs::info "reading targets from ${REPOS_FILE} (field 1 = owner/repo, optional 'pin:<id>' token pins the ruleset)..."
    while IFS= read -r line; do
        # DEFECT D11 (2026-09-14): this block used to read FIELD 2 as the ruleset
        # id to pin. `rollout-targets.tsv` is five-column -- field 2 is the OPEN
        # PR COUNT -- so all 120 rows pinned "ruleset #1/#2/#3", every lookup
        # 404'd, and the run refused 120 of 120. Nothing was written, so the
        # fail-safe held, but the cause was a POSITIONAL assumption about a file
        # this script does not own. A bare column can never again be read as an
        # id: the pin must be an explicit `pin:<digits>` token, in any field.
        pin=""
        case "${line}" in
            *pin:*)
                pin="${line#*pin:}"
                pin="${pin%%[!0-9]*}"
                ;;
        esac
        # First field is always owner/repo; every other field is ignored unless
        # it carried the pin: token above.
        line="${line%%$(printf '\t')*}"
        line="${line%%[[:space:]]*}"
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        [[ "${line}" == */* ]] || gs::die "repos file line is not owner/repo: ${line}"
        local_row="$(gh api "repos/${line}" \
            --jq '[.owner.login, .name, .default_branch, (.archived|tostring)] | @tsv' 2>/dev/null || true)"
        if [[ -z "${local_row}" ]]; then
            gs::warn "cannot read repos/${line} -- skipping (not counted as applied)"
            continue
        fi
        REPO_ROWS+=( "${local_row}$(printf '\t')${pin}" )
    done < "${REPOS_FILE}"
else
    gs::info "fetching repos (limit ${LIMIT})..."
    mapfile -t REPO_ROWS < <(gh repo list "${OWNER}" \
        --limit "${LIMIT}" \
        --json owner,name,defaultBranchRef,isArchived \
        --jq '.[] | [.owner.login, .name, (.defaultBranchRef.name // "main"), (.isArchived|tostring)] | @tsv')
fi

REPO_COUNT="${#REPO_ROWS[@]}"
gs::info "found ${REPO_COUNT} repos"

declare -i N=0 SK_ARC=0 OK=0 FAIL=0 WROTE=0 SAME=0 NOCREATE=0 WOULD=0

for row in "${REPO_ROWS[@]}"; do
    (( N++ )) || true
    IFS=$'\t' read -r row_owner repo_name default_branch is_archived row_pin <<< "${row}"
    prefix="[${N}/${REPO_COUNT}] ${row_owner}/${repo_name}"

    if [[ "${is_archived}" == "true" ]]; then
        gs::debug "${prefix}: skip (archived)"
        (( SK_ARC++ )) || true
        outcome="skipped-archived"
    elif apply_one "${repo_name}" "${default_branch}" "${prefix}" "${row_owner}" "${row_pin:-}"; then
        (( OK++ )) || true
        outcome="${LAST_OUTCOME:-ok}"
        case "${LAST_OUTCOME}" in
            written)            (( WROTE++ ))    || true ;;
            already-canonical)  (( SAME++ ))     || true ;;
            skipped-no-create)  (( NOCREATE++ )) || true ;;
            would-write)        (( WOULD++ ))    || true ;;
        esac
    else
        (( FAIL++ )) || true
        outcome="failed"
    fi

    if [[ -n "${REPORT_FILE}" ]]; then
        gs::report_add "${REPORT_FILE}" \
            "repo = \"${row_owner}/${repo_name}\"" \
            "default_branch = \"${default_branch}\"" \
            "outcome = \"${outcome}\""
    fi
done

# -----------------------------------------------------------------------------
# Summary + exit code.
# -----------------------------------------------------------------------------

gs::banner "Summary"
gs::info "total=${REPO_COUNT}  ok=${OK}  archived=${SK_ARC}  failed=${FAIL}"
# "applied" alone cannot tell a real write from a no-op; a converged run and
# a run that changed nothing looked identical. Break it out.
gs::info "  written=${WROTE}  would-write=${WOULD}  already-canonical=${SAME}  skipped-no-create=${NOCREATE}  ungated=${UNGATED}  ungated-contexts=${UNGATED_CONTEXT}  conditional-contexts=${CONDITIONAL_CONTEXT}  witness-unavailable=${WITNESS_UNAVAILABLE}  merge-method-refused=${MERGE_METHOD_REFUSED}  merge-method-unreadable=${MERGE_METHOD_UNREADABLE}  refused-no-rollback=${REFUSED_NO_ROLLBACK}  refused-witness=${REFUSED_WITNESS}  retired-doubles=${RETIRED_DOUBLES}  retire-refused=${RETIRE_REFUSED}"
[[ -n "${REPORT_FILE}" ]] && gs::info "report: ${REPORT_FILE}"

(( FAIL > 0 )) && exit 1
exit 0
