#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# common.sh — shared library for every script in scripts/.
#
# Provides safe-by-default strict mode, structured logging, dry-run support,
# bounded parallelism, single-instance locking, signal-safe cleanup, GH CLI
# rate-limit + auth + retry, snapshot-based rollback for destructive ops,
# repo-iteration helpers, and a simple flag parser.
#
# Usage:
#   #!/usr/bin/env bash
#   set -uo pipefail
#   SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
#   . "${SCRIPT_DIR}/lib/common.sh"   # or ../lib/common.sh from a subgroup
#   gs::main "$@"
#
# Then define gs::run() doing the real work. The library wires up logging,
# traps, dry-run, --help, and parallel iteration around it.

# Bash-version guard. Several features below (associative arrays, `mapfile`,
# `BASH_REMATCH` semantics) need 4.x+.
if (( BASH_VERSINFO[0] < 4 )); then
    printf '[common.sh] requires bash >= 4 (have %s)\n' "${BASH_VERSION}" >&2
    return 1 2>/dev/null || exit 1
fi

# Idempotent guard — sourcing twice is harmless.
[[ -n "${__GS_COMMON_SH_SOURCED:-}" ]] && return 0
__GS_COMMON_SH_SOURCED=1

# -----------------------------------------------------------------------------
# Strict-by-default mode. We intentionally don't `set -e` globally — the
# caller can opt in via `gs::strict`. Errors propagate explicitly via
# return codes from helpers, so loops that touch many repos keep going.
# -----------------------------------------------------------------------------

gs::strict() {
    set -Eeuo pipefail
    shopt -s inherit_errexit 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Configuration (override via env before sourcing).
# -----------------------------------------------------------------------------

: "${GS_REPOS_DIR:=/var/mnt/eclipse/repos}"      # estate root
: "${GS_LOG_LEVEL:=info}"                        # debug|info|warn|error
: "${GS_DRY_RUN:=0}"                             # 1 = no destructive writes
: "${GS_PARALLEL:=4}"                            # default xargs -P
: "${GS_BACKUP_DIR:=${HOME}/.cache/git-scripts/backups}"
: "${GS_STATE_DIR:=${HOME}/.cache/git-scripts/state}"
: "${GS_LOCK_DIR:=${TMPDIR:-/tmp}/git-scripts.locks}"
: "${GS_REPORT_DIR:=${HOME}/.cache/git-scripts/reports}"
: "${GS_GH_RETRIES:=5}"
: "${GS_GH_RETRY_BASE_S:=2}"
: "${GS_NO_COLOR:=}"                             # set non-empty to force off

mkdir -p "${GS_BACKUP_DIR}" "${GS_STATE_DIR}" "${GS_LOCK_DIR}" "${GS_REPORT_DIR}"

# Colour autodetect: respect $NO_COLOR, $GS_NO_COLOR, and TTY-ness.
if [[ -n "${NO_COLOR:-}${GS_NO_COLOR}" ]] || ! [[ -t 2 ]]; then
    GS_C_RED=  GS_C_YEL=  GS_C_GRN=  GS_C_CYA=  GS_C_BOLD=  GS_C_DIM=  GS_C_RST=
else
    GS_C_RED=$'\033[0;31m'
    GS_C_YEL=$'\033[0;33m'
    GS_C_GRN=$'\033[0;32m'
    GS_C_CYA=$'\033[0;36m'
    GS_C_BOLD=$'\033[1m'
    GS_C_DIM=$'\033[2m'
    GS_C_RST=$'\033[0m'
fi

# -----------------------------------------------------------------------------
# Logging. Timestamps + level + script name. Auto-suppressed below threshold.
# -----------------------------------------------------------------------------

__gs_lvl_num() {
    case "${1,,}" in
        debug) echo 10 ;;
        info)  echo 20 ;;
        warn|warning) echo 30 ;;
        error|err) echo 40 ;;
        *) echo 20 ;;
    esac
}

__gs_should_log() {
    local want; want="$(__gs_lvl_num "$1")"
    local thr;  thr="$(__gs_lvl_num "${GS_LOG_LEVEL}")"
    (( want >= thr ))
}

__gs_log() {
    # $1 = level, rest = message
    local level="$1"; shift
    __gs_should_log "${level}" || return 0
    local colour=""
    case "${level}" in
        debug) colour="${GS_C_DIM}" ;;
        info)  colour="${GS_C_CYA}" ;;
        warn)  colour="${GS_C_YEL}" ;;
        error) colour="${GS_C_RED}" ;;
    esac
    local ts; ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    local tag="${GS_SCRIPT_NAME:-$(basename -- "${BASH_SOURCE[2]:-$0}")}"
    printf '%s%s %-5s %s%s %s\n' \
        "${colour}" "${ts}" "${level^^}" "${tag}" "${GS_C_RST}" "$*" >&2
}

gs::debug()   { __gs_log debug "$@"; }
gs::info()    { __gs_log info  "$@"; }
gs::warn()    { __gs_log warn  "$@"; }
gs::error()   { __gs_log error "$@"; }
gs::die()     { gs::error "$@"; exit 1; }

# Banner — for top-of-script section headers.
gs::banner() {
    local title="$1"
    [[ -t 2 ]] || { gs::info "── ${title} ──"; return; }
    printf '\n%s%s════ %s ════%s\n\n' \
        "${GS_C_BOLD}" "${GS_C_CYA}" "${title}" "${GS_C_RST}" >&2
}

# -----------------------------------------------------------------------------
# Error trap with stack trace. Caller opts in via `gs::strict + gs::install_trap`.
# -----------------------------------------------------------------------------

gs::__on_err() {
    local code=$?
    local cmd="${BASH_COMMAND:-?}"
    # Suppress noise on intentional exits: `exit N` and `return N`.
    case "${cmd}" in
        exit*|return*) return "${code}" ;;
    esac
    gs::error "command failed (exit ${code}): ${cmd}"
    local frame=0
    while caller "${frame}" >&2; do (( frame++ )); done
    return "${code}"
}

gs::install_trap() {
    trap 'gs::__on_err' ERR
    trap 'gs::__on_exit' EXIT
    trap 'gs::__on_signal INT'  INT
    trap 'gs::__on_signal TERM' TERM
}

# Cleanup hooks. Push functions/strings via gs::on_exit; they run LIFO.
declare -a __GS_EXIT_HOOKS=()
gs::on_exit() { __GS_EXIT_HOOKS+=("$1"); }
gs::__on_exit() {
    local code=$?
    local i
    # eval (not `bash -c`) so registered functions from this lib stay in scope.
    for (( i=${#__GS_EXIT_HOOKS[@]}-1 ; i>=0 ; i-- )); do
        eval "${__GS_EXIT_HOOKS[i]}" 2>&1 | sed 's/^/  cleanup: /' >&2 || true
    done
    return "${code}"
}
gs::__on_signal() {
    gs::warn "caught SIG$1, cleaning up..."
    exit 130
}

# Temp-file helper that auto-cleans on exit.
gs::mktemp() {
    local t; t="$(mktemp "${TMPDIR:-/tmp}/gs.XXXXXX")"
    gs::on_exit "rm -f -- '${t}'"
    printf '%s\n' "${t}"
}
gs::mktempdir() {
    local d; d="$(mktemp -d "${TMPDIR:-/tmp}/gs.XXXXXX")"
    gs::on_exit "rm -rf -- '${d}'"
    printf '%s\n' "${d}"
}

# -----------------------------------------------------------------------------
# Single-instance lock. Prevents two copies of the same script tearing the
# estate apart concurrently.
# -----------------------------------------------------------------------------

gs::lock() {
    # $1 = lock name (defaults to script name)
    local name="${1:-${GS_SCRIPT_NAME:-$(basename -- "$0")}}"
    local lockfile="${GS_LOCK_DIR}/${name}.lock"
    if ! command -v flock >/dev/null 2>&1; then
        gs::warn "flock unavailable; skipping single-instance lock"
        return 0
    fi
    exec {GS_LOCK_FD}> "${lockfile}"
    if ! flock -n "${GS_LOCK_FD}"; then
        gs::die "another instance is holding ${lockfile}"
    fi
    gs::debug "acquired lock ${lockfile}"
}

# -----------------------------------------------------------------------------
# Dry-run plumbing. All destructive calls go through `gs::run`; in dry-run
# mode the command is logged, not executed.
# -----------------------------------------------------------------------------

gs::is_dry_run() { [[ "${GS_DRY_RUN}" = "1" ]]; }

# Run a command unless dry-run. Returns the command's exit code, or 0 in
# dry-run.
gs::do() {
    if gs::is_dry_run; then
        gs::info "DRY-RUN: $*"
        return 0
    fi
    "$@"
}

# Like gs::do but for shell-pipeline strings. Use sparingly.
gs::sh() {
    if gs::is_dry_run; then
        gs::info "DRY-RUN: $*"
        return 0
    fi
    bash -c "$*"
}

# -----------------------------------------------------------------------------
# Confirmation prompt. Honours $GS_YES=1 (CI) and dry-run (auto-yes).
# -----------------------------------------------------------------------------

gs::confirm() {
    local prompt="${1:-Continue?}"
    [[ "${GS_YES:-0}" = "1" ]] && return 0
    gs::is_dry_run && return 0
    [[ -t 0 ]] || gs::die "${prompt} — refusing in non-interactive run (set GS_YES=1)"
    local ans
    read -r -p "${prompt} [y/N] " ans
    [[ "${ans,,}" = "y" || "${ans,,}" = "yes" ]]
}

# -----------------------------------------------------------------------------
# Backup / snapshot helpers. Use before mutating files.
#
#   snap=$(gs::snapshot path/to/file)
#   gs::do sed -i 's/foo/bar/' path/to/file
#   trap "gs::rollback '${snap}'" ERR   # optional auto-rollback
# -----------------------------------------------------------------------------

gs::snapshot() {
    local target="$1"
    [[ -e "${target}" ]] || { gs::warn "snapshot: ${target} missing"; return 1; }
    local stamp; stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
    local tag; tag="$(printf '%s' "${target}" | tr '/' '_' | tr -c 'A-Za-z0-9._-' '_')"
    local out="${GS_BACKUP_DIR}/${stamp}-${tag}"
    cp -a -- "${target}" "${out}"
    gs::debug "snapshot ${target} -> ${out}"
    printf '%s\n' "${out}"
}

gs::rollback() {
    local snap="$1" target="$2"
    [[ -e "${snap}" ]] || { gs::error "rollback: snapshot ${snap} missing"; return 1; }
    rm -rf -- "${target}" 2>/dev/null || true
    cp -a -- "${snap}" "${target}"
    gs::warn "rolled back ${target} from ${snap}"
}

# -----------------------------------------------------------------------------
# GH CLI wrappers. Auth-aware, rate-limit-aware, exponential-backoff retries
# on 429/5xx. Replace direct `gh` calls in scripts with these.
# -----------------------------------------------------------------------------

gs::gh_check() {
    command -v gh >/dev/null 2>&1 || gs::die "gh CLI not installed"
    if ! gh auth status >/dev/null 2>&1; then
        gs::die "gh CLI is not authenticated — run 'gh auth login'"
    fi
}

gs::gh_remaining() {
    # Print remaining core-API quota; "?" if unknown.
    gh api -H "Accept: application/vnd.github+json" /rate_limit 2>/dev/null \
        | gs::jq_or_grep '.resources.core.remaining' \
        || printf '?'
}

# Lightweight JSON extractor — uses jq if available, else best-effort grep.
gs::jq_or_grep() {
    if command -v jq >/dev/null 2>&1; then jq -r "$1"
    else grep -oE '"[^"]*"\s*:\s*[0-9]+' | tail -n1 | grep -oE '[0-9]+$'
    fi
}

gs::gh() {
    # Retrying gh wrapper. All args forwarded.
    local attempt=0 wait_s="${GS_GH_RETRY_BASE_S}"
    local out err ec
    while (( attempt < GS_GH_RETRIES )); do
        out="$(gh "$@" 2> >(tee /dev/stderr))" && return 0
        ec=$?
        # On rate-limit (HTTP 403 / 429) or 5xx, back off; else give up.
        if (( ec == 4 )) || gh api /rate_limit 2>/dev/null | grep -q '"remaining": *0'; then
            gs::warn "gh rate-limited; sleeping ${wait_s}s (attempt $((attempt+1))/${GS_GH_RETRIES})"
            sleep "${wait_s}"
            wait_s=$(( wait_s * 2 ))
        else
            return "${ec}"
        fi
        (( attempt++ )) || true
    done
    gs::error "gh failed after ${GS_GH_RETRIES} attempts: gh $*"
    return 1
}

# -----------------------------------------------------------------------------
# Repo iteration. Yields one repo path at a time. Skips non-git dirs.
#
#   while read -r repo; do
#       gs::info "in ${repo##*/}"
#   done < <(gs::repos)
#
# Or in parallel:
#   gs::repos | gs::parallel ./scripts/audit_one.sh {}
# -----------------------------------------------------------------------------

gs::repos() {
    # Honours an optional one-per-line filter list at $GS_REPO_LIST.
    if [[ -n "${GS_REPO_LIST:-}" && -f "${GS_REPO_LIST}" ]]; then
        while IFS= read -r line; do
            [[ -z "${line}" || "${line}" =~ ^# ]] && continue
            local p="${line}"
            [[ "${p}" != /* ]] && p="${GS_REPOS_DIR}/${p}"
            [[ -d "${p}/.git" ]] && printf '%s\n' "${p}"
        done < "${GS_REPO_LIST}"
        return
    fi
    # Default: every direct child of GS_REPOS_DIR that's a git repo.
    local d
    for d in "${GS_REPOS_DIR}"/*/; do
        [[ -d "${d}.git" ]] && printf '%s\n' "${d%/}"
    done
}

# Parallel runner. Reads NUL-or-newline-separated items on stdin and
# substitutes {} into the command. Bounded by $GS_PARALLEL.
gs::parallel() {
    if (( GS_PARALLEL <= 1 )); then
        while IFS= read -r item; do
            [[ -z "${item}" ]] && continue
            "$@" "${item}"
        done
        return
    fi
    xargs -I {} -P "${GS_PARALLEL}" -n 1 -- "$@" {}
}

# -----------------------------------------------------------------------------
# Reporting. Each script can append findings to a structured A2ML/JSON file;
# the estate-report aggregator picks them up.
# -----------------------------------------------------------------------------

gs::report_path() {
    local name="${1:-${GS_SCRIPT_NAME:-$(basename -- "$0" .sh)}}"
    local stamp; stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
    printf '%s/%s-%s.a2ml\n' "${GS_REPORT_DIR}" "${stamp}" "${name}"
}

# Append a finding line. Format: tab-separated key=value pairs.
gs::report_add() {
    local file="$1"; shift
    {
        printf '[finding]\n'
        printf 'timestamp = "%s"\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        local kv
        for kv in "$@"; do
            printf '%s\n' "${kv}"
        done
        printf '\n'
    } >> "${file}"
}

# -----------------------------------------------------------------------------
# Tool-presence assertions. Fail loudly + early when a binary is missing.
# -----------------------------------------------------------------------------

gs::need() {
    local tool
    for tool in "$@"; do
        command -v "${tool}" >/dev/null 2>&1 \
            || gs::die "missing required tool: ${tool}"
    done
}

gs::have() {
    command -v "$1" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
# Tiny flag parser. Consumes the standard flags and leaves the rest in
# $GS_ARGS (an array). Recognised:
#   -n|--dry-run   → GS_DRY_RUN=1
#   -y|--yes       → GS_YES=1
#   -j|--jobs N    → GS_PARALLEL=N
#   -v|--verbose   → GS_LOG_LEVEL=debug
#   -q|--quiet     → GS_LOG_LEVEL=warn
#   -h|--help      → prints $GS_HELP_TEXT (set by caller) and exits 0
#   --             → end of options
# -----------------------------------------------------------------------------

declare -a GS_ARGS=()

gs::parse_args() {
    GS_ARGS=()
    while (( $# > 0 )); do
        case "$1" in
            -n|--dry-run) GS_DRY_RUN=1 ;;
            -y|--yes)     GS_YES=1 ;;
            -j|--jobs)    GS_PARALLEL="${2:?}"; shift ;;
            -v|--verbose) GS_LOG_LEVEL=debug ;;
            -q|--quiet)   GS_LOG_LEVEL=warn ;;
            -h|--help)
                printf '%s\n' "${GS_HELP_TEXT:-No help available.}"
                exit 0 ;;
            --) shift; GS_ARGS+=("$@"); return ;;
            *) GS_ARGS+=("$1") ;;
        esac
        shift
    done
}

# -----------------------------------------------------------------------------
# Self-heal hooks. Each script may register a recovery callback that runs
# automatically once on first ERR; if recovery returns 0, the failed step
# is retried once.
# -----------------------------------------------------------------------------

declare -a __GS_HEAL_HOOKS=()
gs::on_heal() { __GS_HEAL_HOOKS+=("$1"); }

gs::try() {
    # Run a step; on failure, fire heal hooks once and retry.
    local attempt=0
    while (( attempt < 2 )); do
        if "$@"; then return 0; fi
        local ec=$?
        (( attempt == 0 )) || return "${ec}"
        gs::warn "step failed (exit ${ec}); attempting self-heal..."
        local hook
        for hook in "${__GS_HEAL_HOOKS[@]}"; do
            bash -c "${hook}" || gs::warn "heal hook reported failure: ${hook}"
        done
        (( attempt++ )) || true
    done
    return 1
}

# -----------------------------------------------------------------------------
# Pretty footer (counts of warn/error emitted). Call from `gs::on_exit`
# automatically via gs::install_trap_summary.
# -----------------------------------------------------------------------------

declare -i GS_WARN_COUNT=0 GS_ERR_COUNT=0
__gs_log_orig() { __gs_log "$@"; }   # placeholder — counter updated below
gs::warn()  { (( GS_WARN_COUNT++ )) || true; __gs_log warn  "$@"; }
gs::error() { (( GS_ERR_COUNT++ ))  || true; __gs_log error "$@"; }

gs::print_summary() {
    if (( GS_ERR_COUNT > 0 )); then
        gs::__log_summary "${GS_C_RED}" "completed with ${GS_ERR_COUNT} error(s), ${GS_WARN_COUNT} warning(s)"
    elif (( GS_WARN_COUNT > 0 )); then
        gs::__log_summary "${GS_C_YEL}" "completed with ${GS_WARN_COUNT} warning(s)"
    else
        gs::__log_summary "${GS_C_GRN}" "completed cleanly"
    fi
}
gs::__log_summary() {
    local colour="$1"; shift
    [[ -t 2 ]] || { printf '%s\n' "$*" >&2; return; }
    printf '%s%s%s\n' "${colour}" "$*" "${GS_C_RST}" >&2
}

gs::install_trap_summary() {
    gs::on_exit 'gs::print_summary'
}
