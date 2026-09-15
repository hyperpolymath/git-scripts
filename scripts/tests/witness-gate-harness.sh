#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Offline harness for witness_filter_checks() in branch-protection-apply.sh.
#
# It extracts the function from the applier and runs it against a MOCK `gh`, so
# it makes zero API calls and needs no credentials.
#
#   usage: scripts/tests/witness-gate-harness.sh [path-to-applier]
#
# Cases 1-11 are the witness gate proper (union of both check APIs, multi-head
# sampling, and the four fail-safe paths where SILENCE NEVER SUBTRACTS).
# Cases 12-16 are R20, the path-conditional drop.
#
# KILL THE MUTANT: a green run here proves nothing until the fix is deliberately
# reverted and the right case goes red. `--mutate` does exactly that -- it strips
# the R20 predicate out of the extracted function and asserts that 12, 14, 15 and
# 16 FAIL. If they still pass under mutation, this file is not testing what it
# claims to test.
set -uo pipefail

APPLIER="${1:-$(dirname "$0")/../branch-protection-apply.sh}"
MUTATE=0
[[ "${1:-}" == "--mutate" || "${2:-}" == "--mutate" ]] && MUTATE=1
[[ "${APPLIER}" == "--mutate" ]] && APPLIER="$(dirname "$0")/../branch-protection-apply.sh"

gs::warn() { printf 'WARN %s\n' "$*"; }
gs::info() { printf 'INFO %s\n' "$*"; }
declare -i UNGATED_CONTEXT=0 WITNESS_UNAVAILABLE=0 CONDITIONAL_CONTEXT=0
BASEFLAG="$(mktemp)"

A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa   # merged head
B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb   # open head
C=cccccccccccccccccccccccccccccccccccccccc   # branch tip

gh() {
  local args="$*"
  case "$args" in *--base*) echo 1 > "$BASEFLAG" ;; esac
  case "$CASE" in
    statusonly)
      case "$args" in
        *"pr list"*merged*) echo "$A" ;;
        *"pr list"*open*)   : ;;
        *commits*check-runs*) echo '["build","test","CodeQL"]' ;;
        *commits*status*)     echo '["CodeRabbit"]' ;;
        *commits?sha*|*"commits?sha"*) echo "$C" ;;
      esac ;;
    complement)
      case "$args" in
        *"pr list"*merged*) echo "$A" ;;
        *"pr list"*open*)   echo "$B" ;;
        *"commits/$A/check-runs"*) echo '["CodeQL","governance / Code quality + docs"]' ;;
        *"commits/$A/status"*)     echo '[]' ;;
        *"commits/$B/check-runs"*) echo '["build"]' ;;
        *"commits/$B/status"*)     echo '["CodeRabbit"]' ;;
        *"commits/$C/check-runs"*) echo '[]' ;;
        *"commits/$C/status"*)     echo '[]' ;;
        *commits?sha*|*"commits?sha"*) echo "$C" ;;
      esac ;;
    nohead) : ;;
    apierr)
      case "$args" in
        *"pr list"*merged*) echo "$A" ;;
        *commits*check-runs*) echo '{"message":"Not Found"}' ;;
        *commits*status*)     echo '{"message":"Not Found"}' ;;
      esac ;;
    empty)
      case "$args" in
        *"pr list"*merged*) echo "$A" ;;
        *commits*check-runs*) echo '[]' ;;
        *commits*status*)     echo '[]' ;;
      esac ;;
    statusonlynoruns)
      # check-runs READABLE but EMPTY on every head; only a legacy status reports.
      # CodeRabbit's n_check_run_heads rule: a status does NOT prove checks can run.
      case "$args" in
        *"pr list"*merged*) echo "$A" ;;
        *commits*check-runs*) echo '[]' ;;
        *commits*status*)     echo '["CodeRabbit"]' ;;
        *commits?sha*|*"commits?sha"*) echo "$C" ;;
      esac ;;
    paged)
      case "$args" in
        *"pr list"*merged*) echo "$A" ;;
        *commits*check-runs*) printf '["CodeRabbit"]\n["build","test"]\n' ;;
        *commits*status*)     echo '[]' ;;
      esac ;;
    badsha)
      case "$args" in
        *"pr list"*) : ;;
        *commits?sha*|*"commits?sha"*) echo '{"message":"Not Found"}' ;;
      esac ;;
    # R20: every candidate IS witnessed -- that is the whole point. The
    # path-conditional ones must be dropped anyway, on the strength of the name.
    allwitnessed)
      case "$args" in
        *"pr list"*merged*) echo "$A" ;;
        *commits*check-runs*) echo '["build","CodeQL","governance / Code quality + docs",".github/dependabot.yml","config/rulesets/base.json"]' ;;
        *commits*status*)     echo '["CodeRabbit"]' ;;
        *commits?sha*|*"commits?sha"*) echo "$C" ;;
      esac ;;
  esac
}

# Extract the function under test. The range ends at the first column-0 `}`,
# so the applier must not define a helper between WITNESS_OUT= and the function.
FN="$(sed -n '/^WITNESS_OUT=/,/^}$/p' "${APPLIER}")"
if (( MUTATE )); then
  # Reintroduce the defect verbatim: no path-shaped predicate at all.
  FN="$(printf '%s\n' "${FN}" | perl -0pe 's/^    cond="\$\(jq -rn.*?\n    fi\n//ms')"
  printf '=== MUTANT: R20 predicate removed (%s lines stripped) ===\n' \
    "$(( $(sed -n '/^WITNESS_OUT=/,/^}$/p' "${APPLIER}" | wc -l) - $(printf '%s\n' "${FN}" | wc -l) ))"
  # A mutant that does not PARSE reads as red for the wrong reason.
  printf '%s\n' "${FN}" | bash -n - || { echo "MUTANT DOES NOT PARSE -- its red proves nothing"; exit 2; }
fi
eval "${FN}"

fail=0
run() {
  local case_name="$1" checks="$2" expect="$3"
  CASE="${4:-$case_name}"
  UNGATED_CONTEXT=0; WITNESS_UNAVAILABLE=0; CONDITIONAL_CONTEXT=0
  witness_filter_checks o r "$checks" "case=$case_name" main >/dev/null
  local got; got="$(printf '%s' "$WITNESS_OUT" | jq -c '[.[].context]|sort')"
  if [[ "$got" == "$expect" ]]; then printf 'PASS %-18s %s\n' "$case_name" "$got"; return 0
  else printf 'FAIL %-18s got=%s want=%s\n' "$case_name" "$got" "$expect"; fail=1; return 1; fi
}

CHECKS='[{"context":"build"},{"context":"test"},{"context":"CodeQL"},{"context":"CodeRabbit"},{"context":"governance / Code quality + docs"}]'
ALL="$(jq -cn '["CodeRabbit","CodeQL","build","governance / Code quality + docs","test"]|sort')"

echo "--- 1-11: the witness gate ---"
run statusonly "$CHECKS" "$(jq -cn '["CodeRabbit","CodeQL","build","test"]|sort')"
run complement "$CHECKS" "$(jq -cn '["CodeRabbit","CodeQL","build","governance / Code quality + docs"]|sort')"
run nohead "$CHECKS" "$ALL"
run apierr "$CHECKS" "$ALL"
run empty  "$CHECKS" "$ALL"
run badsha "$CHECKS" "$ALL"
run paged  "$CHECKS" "$(jq -cn '["CodeRabbit","build","test"]|sort')"

CASE=statusonly; : > "$BASEFLAG"
witness_filter_checks o r "$CHECKS" "case=basecheck" main >/dev/null
[[ -s "$BASEFLAG" ]] && echo "PASS base-scoped        gh pr list used --base" || { echo "FAIL base-scoped"; fail=1; }

CASE=statusonly; witness_filter_checks o r '[]' "case=emptyinput" main >/dev/null
[[ "$WITNESS_OUT" == '[]' ]] && echo "PASS emptyinput         []" || { echo "FAIL emptyinput"; fail=1; }

CASE=complement; witness_filter_checks o r "$CHECKS" "case=prov" main >/dev/null
case "$WITNESS_PROVENANCE" in
  *"CodeQL@aaaaaaaa"*) echo "PASS provenance         merged head cited first" ;;
  *) echo "FAIL provenance         $WITNESS_PROVENANCE"; fail=1 ;;
esac

echo "--- 12-16: R20, the path-conditional drop ---"
declare -a R20=()

# 12. .github/dependabot.yml is witnessed and must STILL be dropped.
C12='[{"context":"CodeQL"},{"context":"CodeRabbit"},{"context":".github/dependabot.yml"}]'
run "12-dependabot" "$C12" "$(jq -cn '["CodeQL","CodeRabbit"]|sort')" allwitnessed; R20+=($?)
(( CONDITIONAL_CONTEXT == 1 )) && echo "PASS 12-counter         CONDITIONAL_CONTEXT=1" \
  || { echo "FAIL 12-counter         CONDITIONAL_CONTEXT=$CONDITIONAL_CONTEXT"; fail=1; }

# 13. FALSE-POSITIVE GUARD. Spaced job-name separator, no extension -> KEPT.
C13='[{"context":"governance / Code quality + docs"},{"context":"CodeQL"}]'
run "13-governance" "$C13" "$(jq -cn '["governance / Code quality + docs","CodeQL"]|sort')" allwitnessed; R20+=($?)
(( CONDITIONAL_CONTEXT == 0 )) && echo "PASS 13-counter         CONDITIONAL_CONTEXT=0 (nothing dropped)" \
  || { echo "FAIL 13-counter         CONDITIONAL_CONTEXT=$CONDITIONAL_CONTEXT"; fail=1; }

# 14. Dropping empties the set -> no rule at all, caller reports UNGATED.
C14='[{"context":".github/dependabot.yml"}]'
run "14-empties-set" "$C14" '[]' allwitnessed; R20+=($?)

# 15. The CLASS, not the instance: "/" plus a config extension.
C15='[{"context":"config/rulesets/base.json"},{"context":"CodeQL"}]'
run "15-class-not-inst" "$C15" "$(jq -cn '["CodeQL"]|sort')" allwitnessed; R20+=($?)

# 16. Silence never subtracts -- but it must not RESURRECT a conditional one.
#     Witness APIs unreadable: every witnessed context is preserved unfiltered,
#     and the path-shaped one is STILL dropped, because that drop is derived
#     from the name and never from an observation.
C16='[{"context":"build"},{"context":"test"},{"context":"CodeQL"},{"context":".github/dependabot.yml"}]'
run "16-silent-still-drops" "$C16" "$(jq -cn '["build","test","CodeQL"]|sort')" apierr; R20+=($?)
(( WITNESS_UNAVAILABLE == 1 )) && echo "PASS 16-failsafe        WITNESS_UNAVAILABLE=1 (others preserved unfiltered)" \
  || { echo "FAIL 16-failsafe        WITNESS_UNAVAILABLE=$WITNESS_UNAVAILABLE"; fail=1; }


# --- 17: a legacy STATUS is not evidence that checks can RUN -----------------
# Locks in the n_check_run_heads rule (commit 9a820c4). If check-runs is
# READABLE but EMPTY on every head, a CodeRabbit status alone must NOT license
# filtering -- that shape is the 243/391 startup-kill class, where the gates are
# suppressed by a settings bug, not dead. Preserve unfiltered and flag instead.
echo "--- 17: statuses alone do not license filtering ---"
CASE=statusonlynoruns; UNGATED_CONTEXT=0; WITNESS_UNAVAILABLE=0; CONDITIONAL_CONTEXT=0
witness_filter_checks o r "$CHECKS" "case=17" main
g17="$(printf '%s' "$WITNESS_OUT" | jq -c '[.[].context]|sort')"
[[ "$g17" == "$ALL" ]] && echo "PASS 17-status-not-proof  all preserved unfiltered" \
  || { echo "FAIL 17-status-not-proof  got=$g17 want=$ALL"; fail=1; }
(( WITNESS_UNAVAILABLE == 1 )) && echo "PASS 17-flagged           WITNESS_UNAVAILABLE=1" \
  || { echo "FAIL 17-flagged           WITNESS_UNAVAILABLE=$WITNESS_UNAVAILABLE"; fail=1; }
if (( MUTATE )); then
  echo "--- mutant verdict ---"
  # 13 must still PASS under mutation (it asserts nothing is dropped); 12, 14,
  # 15, 16 must all FAIL. Anything else means the test does not test the fix.
  want=(1 0 1 1 1)   # 1 = expected to fail under mutation
  bad=0
  for i in "${!R20[@]}"; do
    (( R20[i] == want[i] )) || { echo "MUTANT-SURVIVED case index $i (got rc=${R20[i]}, want ${want[i]})"; bad=1; }
  done
  (( bad == 0 )) && { echo "KILL CONFIRMED: reverting the predicate reddens exactly 12/14/15/16 and leaves 13 green"; exit 0; }
  echo "MUTANT SURVIVED -- this harness does not prove the R20 fix"; exit 1
fi
exit $fail
