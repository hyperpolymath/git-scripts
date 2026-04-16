#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# ownership_guard.sh — refuse to operate on repositories owned by anyone
# outside the configured allowlist. Source this from any script that
# touches GitHub or pushes to remotes.
#
# Public functions:
#   owner_allowed <owner>            — return 0 if allowed, 1 otherwise
#   assert_owner_allowed <owner>     — exit 78 if owner is not allowed
#   repo_owner_from_remote <path>    — print the GitHub owner of a local repo
#   repo_allowed <path>              — return 0 if a local repo's owner is allowed
#
# Configuration is loaded from the first existing file:
#   $(dirname this)/../../config/owners.config
#   /var/mnt/eclipse/repos/git-scripts/config/owners.config
# falling back to a hard-coded ["hyperpolymath"].

# Idempotent: only load once per shell.
if [[ "${_OWNERSHIP_GUARD_LOADED:-0}" == "1" ]]; then
    return 0 2>/dev/null || true
fi
_OWNERSHIP_GUARD_LOADED=1

_GUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_OWNERS_CONFIG_CANDIDATES=(
    "${_GUARD_DIR}/../../config/owners.config"
    "/var/mnt/eclipse/repos/git-scripts/config/owners.config"
)

_loaded_owners_config=""
for _candidate in "${_OWNERS_CONFIG_CANDIDATES[@]}"; do
    if [[ -f "${_candidate}" ]]; then
        # shellcheck disable=SC1090
        source "${_candidate}"
        _loaded_owners_config="${_candidate}"
        break
    fi
done

if [[ -z "${_loaded_owners_config}" ]]; then
    ALLOWED_OWNERS=("hyperpolymath")
fi

# Lowercase a string (portable; no `${var,,}` to keep bash 3 compat).
_lc() {
    printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

# Return 0 if $1 is in ALLOWED_OWNERS (case-insensitive).
owner_allowed() {
    local needle
    needle="$(_lc "${1:-}")"
    [[ -z "${needle}" ]] && return 1
    local allowed
    for allowed in "${ALLOWED_OWNERS[@]}"; do
        if [[ "${needle}" == "$(_lc "${allowed}")" ]]; then
            return 0
        fi
    done
    return 1
}

# Print the owner of a local git repo, derived from `origin` URL.
# Host-agnostic: works for GitHub, GitLab, Bitbucket, Gitea, codeberg,
# self-hosted servers, and SSH-style URLs. The owner is taken as the
# second-to-last path segment (after stripping a trailing .git).
# Returns 1 (and prints nothing) if no owner can be parsed.
repo_owner_from_remote() {
    local repo_path="${1:-.}"
    local url
    url=$(git -C "${repo_path}" config --get remote.origin.url 2>/dev/null) || return 1
    [[ -z "${url}" ]] && return 1

    # Strip a trailing .git for clean splitting.
    url="${url%.git}"

    local path_part=""

    if [[ "${url}" =~ ^[^[:space:]/@]+@[^:]+:(.+)$ ]]; then
        # SSH-style: [user@]host:path
        path_part="${BASH_REMATCH[1]}"
    elif [[ "${url}" =~ ^[a-zA-Z]+://[^/]+(/.+)$ ]]; then
        # URL-style: proto://[creds@]host[:port]/path
        path_part="${BASH_REMATCH[1]}"
    else
        return 1
    fi

    # Trim leading/trailing slashes, then take the segment before the last.
    path_part="${path_part#/}"
    path_part="${path_part%/}"
    [[ -z "${path_part}" ]] && return 1

    local owner_dir owner
    owner_dir="$(dirname "${path_part}")"
    [[ "${owner_dir}" == "." || "${owner_dir}" == "/" ]] && return 1

    owner="$(basename "${owner_dir}")"
    [[ -z "${owner}" ]] && return 1

    printf '%s\n' "${owner}"
}

# Soft check: returns 0 if the local repo's owner is allowed.
repo_allowed() {
    local owner
    owner="$(repo_owner_from_remote "${1:-.}")" || return 1
    owner_allowed "${owner}"
}

# Hard guard: print an explanation and exit if the owner is not allowed.
# Use at the top of any script that targets a single org/user.
assert_owner_allowed() {
    local owner="${1:-}"
    if owner_allowed "${owner}"; then
        return 0
    fi
    {
        echo ""
        echo "❌ REFUSING to operate on owner '${owner}'."
        echo "   This owner is not in the allowlist for git-scripts."
        echo "   Allowed owners: ${ALLOWED_OWNERS[*]}"
        echo ""
        echo "   To allow it, edit:"
        if [[ -n "${_loaded_owners_config}" ]]; then
            echo "     ${_loaded_owners_config}"
        else
            echo "     config/owners.config"
        fi
        echo "   …or set GIT_SCRIPTS_ALLOWED_OWNERS=\"owner1 owner2\" in the environment."
        echo ""
    } >&2
    exit 78  # EX_CONFIG
}
