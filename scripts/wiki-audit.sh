#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Wiki Audit Script for hyperpolymath repos
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Audits GitHub wiki status across all hyperpolymath repositories.
# Reports: wiki enabled/disabled, wiki has content, page count, page names.
#
# Usage:
#   ./wiki-audit.sh                  # Audit all repos
#   ./wiki-audit.sh --key-only       # Audit key repos only
#   ./wiki-audit.sh --summary        # Print summary stats only
#   ./wiki-audit.sh --template       # Print wiki Home.md template

set -euo pipefail

# --- Configuration ---
OWNER="hyperpolymath"
TMPDIR=""

# --- Ownership safety guard ---
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ownership_guard.sh
source "${_SCRIPT_DIR}/lib/ownership_guard.sh"
assert_owner_allowed "${OWNER}"

# Key repos to always check (subset for quick audits)
KEY_REPOS=(
    boj-server proven echidna gossamer typed-wasm ephapax
    idaptik panll burble verisimdb stapeln ambientops
    developer-ecosystem reposystem nextgen-languages nextgen-databases
    standards typell nickel-augmentation filesoup social-media-tools
    ipv6-tools hyperpolymath-archive patallm-gallery asdf-tool-plugins
)

# Colour output (respects NO_COLOR)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN='' YELLOW='' RED='' BLUE='' BOLD='' RESET=''
fi

# --- Functions ---

cleanup() {
    if [[ -n "$TMPDIR" ]] && [[ -d "$TMPDIR" ]]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

print_template() {
    cat <<'TMPL'
# {{REPO_NAME}}

> {{ONE_LINE_DESCRIPTION}}

## Quick Navigation

- [Getting Started](Getting-Started)
- [Architecture](Architecture)
- [User Guide](User-Guide)
- [Developer Guide](Developer-Guide)
- [FAQ](FAQ)
- [Troubleshooting](Troubleshooting)

## Overview

{{REPO_NAME}} is part of the [Hyperpolymath](https://github.com/hyperpolymath) ecosystem.

**License:** PMPL-1.0-or-later
**Status:** See [ROADMAP](../blob/main/ROADMAP.adoc) and [STATE.scm](../blob/main/.machine_readable/STATE.scm)

## Key Concepts

- ...

## Related Projects

| Project | Relationship |
|---------|-------------|
| ... | ... |

---

*This wiki follows the [Hyperpolymath wiki standard](https://github.com/hyperpolymath/standards).*
TMPL
}

# Check if a wiki has content by attempting to clone it.
# Returns: "content:<page_count>:<page_list>" or "empty" or "error:<msg>"
check_wiki_content() {
    local repo="$1"
    local clone_dir="$TMPDIR/$repo-wiki"

    # Try cloning the wiki repo (quiet, fast)
    if git clone --quiet --depth 1 \
        "https://github.com/$OWNER/$repo.wiki.git" \
        "$clone_dir" 2>/dev/null; then
        # Count .md files
        local pages
        pages=$(find "$clone_dir" -maxdepth 1 -name '*.md' -printf '%f\n' 2>/dev/null | sort)
        local count
        count=$(echo "$pages" | grep -c '.' 2>/dev/null || echo 0)

        if [[ "$count" -gt 0 ]]; then
            echo "content:$count:$(echo "$pages" | tr '\n' ',' | sed 's/,$//')"
        else
            echo "empty"
        fi
        rm -rf "$clone_dir"
    else
        echo "no-wiki-repo"
    fi
}

# Check if wiki is enabled via API
check_wiki_enabled() {
    local repo="$1"
    gh api "repos/$OWNER/$repo" --jq '.has_wiki' 2>/dev/null || echo "api-error"
}

audit_repo() {
    local repo="$1"
    local enabled
    enabled=$(check_wiki_enabled "$repo")

    if [[ "$enabled" == "true" ]]; then
        local content_result
        content_result=$(check_wiki_content "$repo")

        local status_prefix content_type page_count page_list

        case "$content_result" in
            content:*)
                # Parse: content:<count>:<page_list>
                content_type="HAS_CONTENT"
                page_count=$(echo "$content_result" | cut -d: -f2)
                page_list=$(echo "$content_result" | cut -d: -f3-)
                status_prefix="${GREEN}[WIKI+CONTENT]${RESET}"
                ;;
            empty)
                content_type="EMPTY"
                page_count=0
                page_list=""
                status_prefix="${YELLOW}[WIKI+EMPTY]${RESET}"
                ;;
            no-wiki-repo)
                content_type="NO_CONTENT"
                page_count=0
                page_list=""
                status_prefix="${YELLOW}[WIKI+NO_PAGES]${RESET}"
                ;;
            *)
                content_type="ERROR"
                page_count=0
                page_list=""
                status_prefix="${RED}[WIKI+ERROR]${RESET}"
                ;;
        esac

        printf "%-45s %b  pages=%-3s %s\n" \
            "$repo" "$status_prefix" "$page_count" "$page_list"

        # Return structured data for summary
        echo "$repo|$content_type|$page_count|$page_list" >> "$TMPDIR/results.txt"
    elif [[ "$enabled" == "false" ]]; then
        printf "%-45s ${BLUE}[WIKI_DISABLED]${RESET}\n" "$repo"
        echo "$repo|DISABLED|0|" >> "$TMPDIR/results.txt"
    else
        printf "%-45s ${RED}[API_ERROR]${RESET}\n" "$repo"
        echo "$repo|API_ERROR|0|" >> "$TMPDIR/results.txt"
    fi
}

print_summary() {
    local results_file="$TMPDIR/results.txt"
    if [[ ! -f "$results_file" ]]; then
        echo "No results to summarise."
        return
    fi

    local total has_content empty_count no_content disabled errors
    total=$(wc -l < "$results_file" | tr -d ' ')
    has_content=$(grep -c '|HAS_CONTENT|' "$results_file" 2>/dev/null || true)
    has_content=${has_content:-0}
    empty_count=$(grep -c '|EMPTY|' "$results_file" 2>/dev/null || true)
    empty_count=${empty_count:-0}
    no_content=$(grep -c '|NO_CONTENT|' "$results_file" 2>/dev/null || true)
    no_content=${no_content:-0}
    disabled=$(grep -c '|DISABLED|' "$results_file" 2>/dev/null || true)
    disabled=${disabled:-0}
    errors=$(grep -c -E '\|API_ERROR\||\|ERROR\|' "$results_file" 2>/dev/null || true)
    errors=${errors:-0}
    local empty_total=$((empty_count + no_content))

    echo ""
    echo -e "${BOLD}=== Wiki Audit Summary ===${RESET}"
    echo "Total repos audited:    $total"
    echo -e "  ${GREEN}Wiki + content:${RESET}       $has_content"
    echo -e "  ${YELLOW}Wiki enabled, empty:${RESET}  $empty_total"
    echo -e "  ${BLUE}Wiki disabled:${RESET}        $disabled"
    echo -e "  ${RED}Errors:${RESET}               $errors"
    echo ""

    if [[ "$has_content" -gt 0 ]]; then
        echo -e "${BOLD}Repos with wiki content:${RESET}"
        grep '|HAS_CONTENT|' "$results_file" | while IFS='|' read -r repo _ count pages; do
            echo "  $repo ($count pages): $pages"
        done
        echo ""
    fi

    if [[ "$empty_total" -gt 0 ]]; then
        echo -e "${BOLD}Repos with wiki enabled but NO content (candidates for population or disable):${RESET}"
        grep -E '\|EMPTY\||\|NO_CONTENT\|' "$results_file" | while IFS='|' read -r repo _ _ _; do
            echo "  $repo"
        done
        echo ""
    fi
}

# --- Main ---

TMPDIR=$(mktemp -d)
touch "$TMPDIR/results.txt"

case "${1:-}" in
    --template)
        print_template
        exit 0
        ;;
    --key-only)
        echo -e "${BOLD}Wiki audit: key repos only${RESET}"
        echo "Auditing ${#KEY_REPOS[@]} repos..."
        echo ""
        for repo in "${KEY_REPOS[@]}"; do
            audit_repo "$repo"
        done
        print_summary
        ;;
    --summary)
        echo -e "${BOLD}Wiki audit: all repos (summary only)${RESET}"
        # Fetch all repo names
        mapfile -t ALL_REPOS < <(gh api users/$OWNER/repos --paginate --jq '.[].name' 2>/dev/null | sort)
        echo "Auditing ${#ALL_REPOS[@]} repos..."
        echo ""
        for repo in "${ALL_REPOS[@]}"; do
            audit_repo "$repo" > /dev/null
        done
        print_summary
        ;;
    ""|--all)
        echo -e "${BOLD}Wiki audit: all repos${RESET}"
        mapfile -t ALL_REPOS < <(gh api users/$OWNER/repos --paginate --jq '.[].name' 2>/dev/null | sort)
        echo "Auditing ${#ALL_REPOS[@]} repos..."
        echo ""
        for repo in "${ALL_REPOS[@]}"; do
            audit_repo "$repo"
        done
        print_summary
        ;;
    --help|-h)
        echo "Usage: wiki-audit.sh [--key-only|--all|--summary|--template|--help]"
        echo ""
        echo "  (default)     Audit all repos with full output"
        echo "  --key-only    Audit key repos only (fast)"
        echo "  --summary     Audit all repos, print summary only"
        echo "  --template    Print wiki Home.md template"
        echo "  --help        This message"
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        echo "Run: wiki-audit.sh --help"
        exit 1
        ;;
esac
