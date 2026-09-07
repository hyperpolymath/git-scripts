#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
# Offline contract tests: the fake gh records every attempted mutation.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APPLIER="${APPLIER_UNDER_TEST:-${ROOT}/scripts/branch-protection-apply.sh}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ruleset-tests.XXXXXX")"
trap 'rm -rf -- "${TEST_ROOT}"' EXIT
mkdir -p "${TEST_ROOT}/bin"

cat > "${TEST_ROOT}/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${CASE_DIR}/calls"
args=("$@")
filter=''
method=GET
for ((i=0; i<$#; i++)); do
    case "${args[i]}" in
        --jq) filter="${args[i+1]}" ;;
        --method) method="${args[i+1]}" ;;
    esac
done
emit() {
    if [[ -n "${filter}" ]]; then jq -r "${filter}"; else cat; fi
}
if [[ "$1" == auth ]]; then exit 0; fi
if [[ "$*" == *'/rate_limit'* ]]; then
    printf '%s\n' '{"resources":{"core":{"remaining":4000}}}' | emit
    exit 0
fi
if [[ "$1 $2" == 'repo list' ]]; then
    if [[ "${SCENARIO}" == inventory-fail ]]; then
        echo 'fixture: repository API unavailable' >&2; exit 1
    fi
    emit < "${CASE_DIR}/repos.json"
    exit 0
fi
if [[ "$1 $2" == 'repo view' ]]; then
    jq '.[0]' "${CASE_DIR}/repos.json" | emit
    exit 0
fi
if [[ "$1" != api ]]; then echo "unexpected gh call: $*" >&2; exit 2; fi
endpoint="$2"
if [[ "${method}" != GET ]]; then
    printf '%s %s\n' "${method}" "${endpoint}" >> "${CASE_DIR}/writes"
    cat > "${CASE_DIR}/payload.json"
    if [[ "${SCENARIO}" == write-fail ]]; then
        echo 'fixture: ambiguous update failure' >&2; exit 1
    fi
    jq -s '.[0] * .[1]' "${CASE_DIR}/before.json" "${CASE_DIR}/payload.json" > "${CASE_DIR}/after.json"
    cat "${CASE_DIR}/after.json"
    exit 0
fi
if [[ "${endpoint}" == */rulesets || "${endpoint}" == */rulesets\?* ]]; then
    if [[ "${SCENARIO}" == list-fail ]]; then
        echo 'fixture: rulesets HTTP 403' >&2; exit 1
    fi
    if [[ "$*" == *--slurp* ]]; then
        emit < "${CASE_DIR}/pages.json"
    else
        jq 'add' "${CASE_DIR}/pages.json" | emit
    fi
    exit 0
fi
if [[ "${endpoint,,}" == repos/hyperpolymath/example/rulesets/42 ]]; then
    reads=0
    if [[ -f "${CASE_DIR}/reads" ]]; then read -r reads < "${CASE_DIR}/reads"; fi
    reads=$((reads+1)); printf '%s\n' "${reads}" > "${CASE_DIR}/reads"
    if [[ "${SCENARIO}" == detail-fail ]] ||
        [[ "${SCENARIO}" == verify-fail && "${reads}" -ge 3 ]]; then
        echo 'fixture: detail HTTP 500' >&2; exit 1
    fi
    if [[ "${SCENARIO}" == racing && "${reads}" -ge 2 ]]; then
        jq '.conditions.ref_name.exclude += ["refs/heads/release"]' "${CASE_DIR}/before.json" | emit
    elif [[ -f "${CASE_DIR}/after.json" && "${SCENARIO}" != mismatch ]]; then
        if [[ "${SCENARIO}" == reordered ]]; then
            jq '.rules |= reverse' "${CASE_DIR}/after.json" | emit
        elif [[ "${SCENARIO}" == altered-parameter ]]; then
            jq '(.rules[] | select(.type == "pull_request") | .parameters.required_approving_review_count)=0' \
                "${CASE_DIR}/after.json" | emit
        else
            emit < "${CASE_DIR}/after.json"
        fi
    else
        emit < "${CASE_DIR}/before.json"
    fi
    exit 0
fi
echo "unexpected endpoint: ${endpoint}" >&2; exit 2
MOCK
chmod +x "${TEST_ROOT}/bin/gh"

fixture() {
    CASE_DIR="${TEST_ROOT}/$1"
    export CASE_DIR
    mkdir -p "${CASE_DIR}"
    : > "${CASE_DIR}/writes"
    cat > "${CASE_DIR}/repos.json" <<'JSON'
[{"name":"example","nameWithOwner":"hyperpolymath/example","defaultBranchRef":{"name":"main"},"isArchived":false}]
JSON
    cat > "${CASE_DIR}/pages.json" <<'JSON'
[[{"id":17,"name":"immutable-tags","target":"tag","source_type":"Repository","source":"hyperpolymath/example"}],
 [{"id":42,"name":"Optimus-Branch","target":"branch","source_type":"Repository","source":"hyperpolymath/example"},
  {"id":43,"name":"Acceptance","target":"branch","source_type":"Repository","source":"hyperpolymath/example"}]]
JSON
    cat > "${CASE_DIR}/before.json" <<'JSON'
{"id":42,"name":"Optimus-Branch","target":"branch","source_type":"Repository","source":"hyperpolymath/example","enforcement":"active",
 "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH","refs/heads/release/**"],"exclude":["refs/heads/release/test"]}},
 "bypass_actors":[{"actor_type":"Integration","actor_id":12526,"bypass_mode":"pull_request"}],
 "rules":[{"type":"deletion"},
 {"type":"pull_request","parameters":{"required_approving_review_count":2,"require_code_owner_review":true,"required_review_thread_resolution":true}},
 {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"quality","integration_id":12526}]}},
 {"type":"required_deployments","parameters":{"required_deployment_environments":["staging"]}},
 {"type":"code_scanning","parameters":{"code_scanning_tools":[{"tool":"CodeQL","security_alerts_threshold":"high_or_higher","alerts_threshold":"errors"}]}}]}
JSON
}

change() {
    local file="$1" filter="$2"
    jq "${filter}" "${CASE_DIR}/${file}.json" > "${CASE_DIR}/changed.json"
    mv "${CASE_DIR}/changed.json" "${CASE_DIR}/${file}.json"
}

run_case() {
    local name="$1" expected="$2" writes="$3" rc=0
    shift 3
    if PATH="${TEST_ROOT}/bin:${PATH}" SCENARIO="${name}" \
        GS_BACKUP_DIR="${CASE_DIR}/backups" GS_STATE_DIR="${CASE_DIR}/state" \
        GS_LOCK_DIR="${CASE_DIR}/locks" GS_REPORT_DIR="${CASE_DIR}/reports" \
        GS_GH_RETRY_BASE_S=0 GS_NO_COLOR=1 \
        GIT_SCRIPTS_ALLOWED_OWNERS=hyperpolymath \
        bash "${APPLIER}" --yes "$@" > "${CASE_DIR}/output" 2>&1; then
        rc=0
    else
        rc=$?
    fi
    if { [[ "${expected}" == success ]] && (( rc != 0 )); } ||
       { [[ "${expected}" == failure ]] && (( rc == 0 )); } ||
       [[ "$(wc -l < "${CASE_DIR}/writes")" -ne "${writes}" ]]; then
        cat "${CASE_DIR}/output" >&2
        cat "${CASE_DIR}/writes" >&2
        echo "FAIL ${name}: exit=${rc}, expected=${expected}, expected writes=${writes}" >&2
        exit 1
    fi
    printf 'PASS %s\n' "${name}"
}

for scenario in inventory-fail list-fail detail-fail racing; do
    fixture "${scenario}"
    run_case "${scenario}" failure 0
done
fixture dry-run-read-fail
run_case detail-fail failure 0 --dry-run
fixture malformed-list
printf '%s\n' '{"message":"Not Found"}' > "${CASE_DIR}/pages.json"
run_case malformed-list failure 0
fixture missing
printf '%s\n' '[[]]' > "${CASE_DIR}/pages.json"
run_case missing failure 0
fixture ambiguous
change pages '.[1] += [ (.[1][0] | .id=44 | .name="Base") ]'
run_case ambiguous failure 0
fixture inherited
change pages '.[1][0].source_type="Organization"'
run_case inherited failure 0
fixture wrong-detail
change before '.id=99'
run_case wrong-detail failure 0
fixture malformed-detail
change before '.rules=null'
run_case malformed-detail failure 0
fixture inactive
change before '.enforcement="disabled"'
run_case inactive failure 0
fixture over-limit
change repos '. += [(.[0] | .name="second" | .nameWithOwner="hyperpolymath/second")]'
run_case over-limit failure 0 --limit 1
fixture foreign-owner
change repos '.[0].nameWithOwner="someone-else/example"'
run_case foreign-owner failure 0
fixture empty-repo
change repos '.[0].defaultBranchRef=null'
run_case empty-repo failure 0
fixture archived
change repos '.[0].isArchived=true | .[0].defaultBranchRef=null'
run_case archived success 0
fixture empty-inventory
printf '%s\n' '[]' > "${CASE_DIR}/repos.json"
run_case empty-inventory success 0
fixture dry-run
run_case dry-run success 0 --dry-run
fixture single-repo
run_case single-repo success 0 --repo example --dry-run
fixture wrong-single-repo
run_case wrong-single-repo failure 0 --repo unexpected --dry-run
fixture mixed-case-owner
run_case mixed-case-owner success 0 --owner HyperPolyMath --repo ExAMPle --dry-run
fixture reordered
run_case reordered success 1
fixture altered-parameter
run_case altered-parameter failure 1

fixture repair
run_case repair success 1
[[ "$(cat "${CASE_DIR}/writes")" == 'PUT repos/hyperpolymath/example/rulesets/42' ]]
jq -e --slurpfile before "${CASE_DIR}/before.json" '
  . as $after | $before[0] as $before |
  .name == $before.name and .target == $before.target and
  .enforcement == $before.enforcement and .conditions == $before.conditions and
  .bypass_actors == $before.bypass_actors and
  all($before.rules[]; . as $rule | $after.rules | index($rule) != null) and
  all(["deletion","non_fast_forward","required_linear_history","required_signatures"][];
      . as $type | [$after.rules[] | select(.type == $type)] | length == 1) and
  (.rules | length) == ($before.rules | length) + 3
' "${CASE_DIR}/payload.json" >/dev/null
cmp "${CASE_DIR}/before.json" "${CASE_DIR}"/state/ruleset-*.json
# A second invocation against the updated state is a genuine no-op.
cp "${CASE_DIR}/after.json" "${CASE_DIR}/before.json"
: > "${CASE_DIR}/writes"
run_case idempotent success 0

fixture legacy-base
change pages '.[1][0].name="Base"'
change before '.name="Base"'
run_case legacy-base success 1
for scenario in write-fail verify-fail mismatch; do
    fixture "${scenario}"
    run_case "${scenario}" failure 1
done
echo 'All offline ruleset contract tests passed.'
