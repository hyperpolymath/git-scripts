#!/usr/bin/env bash
# R25 retire-doubles predicate harness.
#
# The predicate is EXTRACTED FROM THE APPLIER, never copied. A harness carrying
# its own copy of the rule passes happily against a stale duplicate while the
# real script has drifted -- the exact failure mode the exactness spine exists
# to prevent. If the extraction stops matching, this harness FAILS LOUDLY
# rather than falling back to an inline copy.
#
#   normal:  bash retire-doubles-guard-harness.sh
#   mutants: bash retire-doubles-guard-harness.sh --mutate-substring
#            bash retire-doubles-guard-harness.sh --mutate-no-authz
#
# A green suite proves nothing until a mutant is killed AND the kill is
# DISCRIMINATING -- only the targeted cases may flip.
set -uo pipefail

TARGET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/branch-protection-apply.sh"
[[ -r "${TARGET}" ]] || { echo "FATAL: cannot read ${TARGET}"; exit 3; }

MUTATE="${1:-}"

# --- extract the generation split, verbatim from the applier ------------------
SPLIT="$(sed -n '/^        local old_ids="" new_ids="" i$/,/^        done$/p' "${TARGET}")"
[[ -n "${SPLIT}" ]] || { echo "FATAL: could not extract the generation split from ${TARGET}"; exit 3; }
# De-localise the DECLARATION only. The generation comparison below it -- the
# thing under test -- is never rewritten.
SPLIT="$(printf '%s\n' "${SPLIT}" | sed 's/^        local old_ids="" new_ids="" i$/        old_ids=""; new_ids=""/')"
printf '%s\n' "${SPLIT}" | /usr/bin/grep -q 'local ' \
  && { echo "FATAL: extraction still carries a local declaration"; exit 3; }

# --- extract the authorisation condition, verbatim from the applier -----------
COND="$(sed -n '/^        if \[\[ -n "\${RETIRE_DOUBLES_FILE}" \]\] \\$/,/; then$/p' "${TARGET}")"
[[ -n "${COND}" ]] || { echo "FATAL: could not extract the retire condition from ${TARGET}"; exit 3; }

# Mutants are applied with sed, NOT with ${VAR//pat/rep}. Bash parameter
# expansion mis-parses any pattern containing a `}` -- and these patterns all
# contain `${RETIRE_DOUBLES_FILE}` -- which silently produced a MANGLED
# condition. Its suite went red on a PARSE ERROR while looking like a kill, and
# the cases it reddened were the wrong ones. A mutant must be VALID before its
# red means anything.
COND_BEFORE="${COND}"
case "${MUTATE}" in
  --mutate-substring)
      # Defect: substring / any-position match instead of whole-line fixed match,
      # so a listed repo name would authorise a different repo that extends it.
      COND="$(printf '%s\n' "${COND}" | sed 's/grep -qixF/grep -qF/')" ;;
  --mutate-no-authz)
      # Defect: the allow-list check dropped, leaving ONLY the id-generation
      # heuristic to decide whether a ruleset may be permanently DELETED.
      COND="$(printf '%s\n' "${COND}" \
          | sed -e 's|^\( *\)if \[\[ -n "${RETIRE_DOUBLES_FILE}" \]\] \\$|\1if [[ -n "x" ]] \\|' \
                -e 's|^\( *\)&& /usr/bin/grep -qixF .*\\$|\1\&\& true \\|')" ;;
  "") : ;;
  *) echo "FATAL: unknown flag ${MUTATE}"; exit 3 ;;
esac
if [[ -n "${MUTATE}" ]]; then
    [[ "${COND}" != "${COND_BEFORE}" ]] \
        || { echo "FATAL: mutant ${MUTATE} changed NOTHING -- its result would be meaningless"; exit 3; }
    printf '%s\n' "${COND}" | /usr/bin/grep -q '\${RETIRE_DOUBLES_FILE}\"/\|}\"/-n' \
        && { echo "FATAL: mutant ${MUTATE} is MANGLED, not mutated"; exit 3; }
fi

# Turn the extracted condition into a predicate function. The body is replaced,
# the CONDITION is not.
eval "retire_authorised() {
${SPLIT}
${COND}
    return 0
  else
    return 1
  fi
}"

NEWGEN_MIN=20000000
OWNER=hyperpolymath
LIST="$(mktemp)"; trap 'rm -f "${LIST}" "${LIST}.2"' EXIT
cat > "${LIST}" <<'EOF'
hyperpolymath/tropical-types
hyperpolymath/the-metadatastician
hyperpolymath/squisher-corpus
hyperpolymath/marches
EOF

fail=0
run() { # name  repo  ids(newline-sep)  listfile  expect
  local name="$1" repo="$2" want="$5" got
  repo_name="$2"; ids="$3"; RETIRE_DOUBLES_FILE="$4"
  id_count="$(printf '%s' "${ids}" | /usr/bin/grep -c . || true)"
  if retire_authorised; then got=RETIRE; else got=REFUSE; fi
  if [[ "${got}" == "${want}" ]]; then printf 'PASS %-22s %s\n' "${name}" "${got}"
  else printf 'FAIL %-22s got=%s want=%s\n' "${name}" "${got}" "${want}"; fail=1; fi
}

OLD=14936606; NEW=22942837
run authorised-1+1      tropical-types        "${OLD}"$'\n'"${NEW}"      "${LIST}" RETIRE
run authorised-order    tropical-types        "${NEW}"$'\n'"${OLD}"      "${LIST}" RETIRE
run authorised-three    tropical-types        "${OLD}"$'\n'"${NEW}"$'\n'22960461 "${LIST}" REFUSE
run authorised-both-old tropical-types        "${OLD}"$'\n'18528571      "${LIST}" REFUSE
run authorised-both-new tropical-types        "${NEW}"$'\n'22960461      "${LIST}" REFUSE
run unauthorised-repo   gitbot-fleet          "${OLD}"$'\n'"${NEW}"      "${LIST}" REFUSE
run e1-hand-built       echidna               "${OLD}"$'\n'"${NEW}"      "${LIST}" REFUSE
run no-list-at-all      tropical-types        "${OLD}"$'\n'"${NEW}"      ""        REFUSE
run missing-list-file   tropical-types        "${OLD}"$'\n'"${NEW}"      /nonexistent/nope REFUSE
# Substring safety, BOTH directions -- a listed name must never authorise a
# different repo whose name merely contains or extends it.
run suffix-not-listed   marches-extra         "${OLD}"$'\n'"${NEW}"      "${LIST}" REFUSE
printf 'hyperpolymath/marches-extra\n' > "${LIST}.2"
run prefix-not-listed   marches               "${OLD}"$'\n'"${NEW}"      "${LIST}.2" REFUSE
rm -f "${LIST}.2"
# Generation boundary is exact, not approximate.
run boundary-exact      tropical-types        19999999$'\n'20000000      "${LIST}" RETIRE
run boundary-both-below tropical-types        19999998$'\n'19999999      "${LIST}" REFUSE

# The seven REAL measured pairs (census 2026-09-15). These are the only repos
# the owner authorised, so the predicate must say RETIRE on every one of them
# and the allow-list must contain every one -- a boundary that is merely
# plausible is not enough.
cat > "${LIST}" <<'LIST7'
hyperpolymath/tropical-types
hyperpolymath/the-metadatastician
hyperpolymath/squisher-corpus
hyperpolymath/self-destructing-git-garbage
hyperpolymath/polystack
hyperpolymath/network-outpost
hyperpolymath/marches
LIST7
while read -r r o n; do
  run "real:${r}" "${r}" "${o}"$'\n'"${n}" "${LIST}" RETIRE
done <<'PAIRS'
tropical-types 14936606 22942837
the-metadatastician 15402978 22941182
squisher-corpus 14968745 22960461
self-destructing-git-garbage 18528571 22960855
polystack 18639852 22961049
network-outpost 18874804 22961091
marches 18875273 22941164
PAIRS

if [[ -n "${MUTATE}" ]]; then
  if (( fail )); then
    echo "KILL CONFIRMED: mutant caused the guard cases to fail"
    exit 0
  fi
  echo "MUTANT SURVIVED: guard cases stayed green"
  exit 1
fi

if (( fail )); then echo "SUITE RED"; else echo "SUITE GREEN"; fi
exit "${fail}"
