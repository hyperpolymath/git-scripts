#!/usr/bin/env bash
# Regression harness for the MERGE-METHOD preflight readability guard.
#
# The defect (measured 2026-09-15, 22 false SQUASH-DISABLED verdicts in one run):
# a GitHub 403/404 error BODY is valid JSON, so
#   jq '{merge:.allow_merge_commit, squash:.allow_squash_merge, rebase:.allow_rebase_merge}'
# over it returns a well-formed object of NULLs. A guard asking `type == "object"`
# therefore PASSES on a read that never reached the repo, every field compares
# unequal to "true", and "could not look" is reported as "the setting is off".
#
# The guard expression is EXTRACTED FROM THE SCRIPT, never copied, so this test
# cannot silently pass against a stale duplicate of the predicate.
#
# Usage:  merge-method-guard-harness.sh [--mutate]
#         --mutate reinstates the defective predicate and asserts the controls go RED.
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/../branch-protection-apply.sh"
[[ -r "${TARGET}" ]] || { echo "FATAL: cannot read ${TARGET}"; exit 3; }

MUTATE=0
[[ "${1:-}" == "--mutate" ]] && MUTATE=1

# Extract the live predicate from the applier itself.
GUARD="$(grep -oE "\(\.merge\|type==\"boolean\"\).*\(\.rebase\|type==\"boolean\"\)" "${TARGET}" | head -1)"
if (( MUTATE )); then
    GUARD='type == "object"'          # the defect, verbatim
elif [[ -z "${GUARD}" ]]; then
    echo "FATAL: could not extract the guard predicate from ${TARGET}"; exit 3
fi
echo "GUARD: ${GUARD}"

# jq projection exactly as the applier applies it
PROJ='{merge:.allow_merge_commit, squash:.allow_squash_merge, rebase:.allow_rebase_merge}'

# readable() -> 0 when the guard accepts the response as a genuine repo read
readable() { printf '%s' "$1" | jq "${PROJ}" 2>/dev/null | jq -e "${GUARD}" >/dev/null 2>&1; }

fail=0
check() { # name  body  want(readable|unreadable)
    local name="$1" body="$2" want="$3" got
    if readable "${body}"; then got=readable; else got=unreadable; fi
    if [[ "${got}" == "${want}" ]]; then printf 'PASS %-22s %s\n' "${name}" "${got}"
    else printf 'FAIL %-22s got=%s want=%s\n' "${name}" "${got}" "${want}"; fail=1; fi
}

REAL_ON='{"allow_merge_commit":true,"allow_squash_merge":true,"allow_rebase_merge":true}'
REAL_OFF='{"allow_merge_commit":true,"allow_squash_merge":false,"allow_rebase_merge":true}'
ERR_403='{"message":"API rate limit exceeded for user ID 6759885","documentation_url":"https://docs.github.com/","status":"403"}'
ERR_404='{"message":"Not Found","documentation_url":"https://docs.github.com/","status":"404"}'
EMPTY=''
HTML='<html><body>502 Bad Gateway</body></html>'

# Controls that MUST stay readable -- a real answer, whatever it says.
check real-squash-on    "${REAL_ON}"  readable
check real-squash-off   "${REAL_OFF}" readable
# THE REGRESSION CONTROLS -- these are what the mutant flips.
check rate-limit-403    "${ERR_403}"  unreadable
check not-found-404     "${ERR_404}"  unreadable
# Non-JSON can never be mistaken for a read, mutant or not.
check empty-response    "${EMPTY}"    unreadable
check html-error-page   "${HTML}"     unreadable

# A readable response must still distinguish ON from OFF, or the fix would have
# traded a false refusal for a false write.
sq() { printf '%s' "$1" | jq -r "${PROJ} | .squash"; }
[[ "$(sq "${REAL_ON}")"  == "true"  ]] && echo "PASS squash-on-detected  true"  || { echo "FAIL squash-on-detected";  fail=1; }
[[ "$(sq "${REAL_OFF}")" == "false" ]] && echo "PASS squash-off-detected false" || { echo "FAIL squash-off-detected"; fail=1; }

echo
if (( MUTATE )); then
    if (( fail )); then echo "KILL CONFIRMED -- the defective predicate fails the controls it must fail."; exit 0
    else echo "MUTANT SURVIVED -- the suite does not test the defect. The tests are worthless."; exit 1; fi
fi
(( fail )) && echo "SUITE RED" || echo "SUITE GREEN"
exit $fail
