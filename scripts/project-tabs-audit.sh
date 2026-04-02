#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# project-tabs-audit.sh — Audit and standardize GitHub "About" metadata
# for all hyperpolymath repos (description, homepage URL, topics).
#
# Author: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# Usage:
#   ./project-tabs-audit.sh              # Full audit (read-only)
#   ./project-tabs-audit.sh --fix-topics # Also add missing mandatory topics (WRITES)
#   ./project-tabs-audit.sh --json       # Output raw JSON for each repo
#
# Requirements: gh (GitHub CLI), jq
#
# This script NEVER modifies descriptions or homepage URLs automatically.
# Those require human judgment. It only reports gaps and optionally adds
# mandatory topics.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OWNER="hyperpolymath"

# Mandatory topics — every repo SHOULD have these
MANDATORY_TOPICS=("hyperpolymath" "palimpsest")

# Recommended topics by repo category (used for suggestions, not enforcement)
declare -A CATEGORY_TOPICS
CATEGORY_TOPICS[monorepo]="monorepo"
CATEGORY_TOPICS[game]="game"
CATEGORY_TOPICS[database]="database"
CATEGORY_TOPICS[language]="programming-language"
CATEGORY_TOPICS[tool]="developer-tools"
CATEGORY_TOPICS[standard]="standards"

# Repos to skip (forks, archived, etc.)
SKIP_REPOS=()

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

MODE="audit"
JSON_MODE=false
TOTAL=0
MISSING_DESC=0
MISSING_URL=0
MISSING_TOPICS=0
MISSING_MANDATORY_TOPIC=0

# Repos with issues, stored for summary
declare -a REPOS_NO_DESC=()
declare -a REPOS_NO_URL=()
declare -a REPOS_NO_TOPICS=()
declare -a REPOS_NO_MANDATORY=()

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --fix-topics) MODE="fix-topics" ;;
        --json)       JSON_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--fix-topics] [--json] [--help]"
            echo ""
            echo "  --fix-topics  Add missing mandatory topics (hyperpolymath, palimpsest)"
            echo "  --json        Output raw JSON per repo"
            echo "  --help        Show this help"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Check if a value is in an array
contains() {
    local needle="$1"
    shift
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Print a colored status line
status() {
    local color="$1" symbol="$2" msg="$3"
    case "$color" in
        red)    printf "\033[31m%s\033[0m %s\n" "$symbol" "$msg" ;;
        yellow) printf "\033[33m%s\033[0m %s\n" "$symbol" "$msg" ;;
        green)  printf "\033[32m%s\033[0m %s\n" "$symbol" "$msg" ;;
        *)      printf "%s %s\n" "$symbol" "$msg" ;;
    esac
}

# ---------------------------------------------------------------------------
# Main audit loop
# ---------------------------------------------------------------------------

echo "======================================================================="
echo "  GitHub Project Metadata Audit — ${OWNER}"
echo "  $(date -Iseconds)"
echo "======================================================================="
echo ""

# Fetch all repo names (non-archived, non-fork, source only)
echo "Fetching repository list..."
REPOS=$(gh repo list "$OWNER" \
    --limit 500 \
    --source \
    --no-archived \
    --json name \
    --jq '.[].name' | sort)

REPO_COUNT=$(echo "$REPOS" | wc -l)
echo "Found ${REPO_COUNT} source (non-archived, non-fork) repos."
echo ""

# Process each repo
while IFS= read -r repo; do
    # Skip if in skip list
    if contains "$repo" "${SKIP_REPOS[@]+"${SKIP_REPOS[@]}"}"; then
        continue
    fi

    TOTAL=$((TOTAL + 1))

    # Fetch metadata
    meta=$(gh repo view "${OWNER}/${repo}" \
        --json description,homepageUrl,repositoryTopics 2>/dev/null || echo '{}')

    desc=$(echo "$meta" | jq -r '.description // ""')
    url=$(echo "$meta" | jq -r '.homepageUrl // ""')
    topics=$(echo "$meta" | jq -r '(.repositoryTopics // []) | [.[].name] | join(",")')

    if $JSON_MODE; then
        echo "$meta" | jq --arg name "$repo" '. + {name: $name}'
        continue
    fi

    # --- Check description ---
    has_desc=true
    if [[ -z "$desc" ]]; then
        has_desc=false
        MISSING_DESC=$((MISSING_DESC + 1))
        REPOS_NO_DESC+=("$repo")
    fi

    # --- Check homepage URL ---
    has_url=true
    if [[ -z "$url" ]]; then
        has_url=false
        MISSING_URL=$((MISSING_URL + 1))
        REPOS_NO_URL+=("$repo")
    fi

    # --- Check topics ---
    has_topics=true
    if [[ -z "$topics" ]]; then
        has_topics=false
        MISSING_TOPICS=$((MISSING_TOPICS + 1))
        REPOS_NO_TOPICS+=("$repo")
    fi

    # --- Check mandatory topics ---
    missing_mandatory=()
    IFS=',' read -ra topic_arr <<< "$topics"
    for mtopic in "${MANDATORY_TOPICS[@]}"; do
        if ! contains "$mtopic" "${topic_arr[@]+"${topic_arr[@]}"}"; then
            missing_mandatory+=("$mtopic")
        fi
    done

    has_all_mandatory=true
    if [[ ${#missing_mandatory[@]} -gt 0 ]]; then
        has_all_mandatory=false
        MISSING_MANDATORY_TOPIC=$((MISSING_MANDATORY_TOPIC + 1))
        REPOS_NO_MANDATORY+=("${repo}  (missing: ${missing_mandatory[*]})")
    fi

    # --- Print per-repo status ---
    # Only print repos with issues (to keep output manageable)
    if ! $has_desc || ! $has_url || ! $has_topics || ! $has_all_mandatory; then
        echo "--- ${OWNER}/${repo} ---"
        if $has_desc; then
            status green "[ok]" "Description: ${desc:0:80}"
        else
            status red "[!!]" "Description: MISSING"
        fi
        if $has_url; then
            status green "[ok]" "Homepage: ${url}"
        else
            status yellow "[--]" "Homepage: not set"
        fi
        if $has_topics; then
            if $has_all_mandatory; then
                status green "[ok]" "Topics: ${topics}"
            else
                status yellow "[~~]" "Topics: ${topics}  (missing mandatory: ${missing_mandatory[*]})"
            fi
        else
            status red "[!!]" "Topics: NONE"
        fi
        echo ""
    fi

    # --- Optionally fix mandatory topics ---
    if [[ "$MODE" == "fix-topics" && ${#missing_mandatory[@]} -gt 0 ]]; then
        echo "  -> Adding mandatory topics: ${missing_mandatory[*]}"
        for mtopic in "${missing_mandatory[@]}"; do
            gh repo edit "${OWNER}/${repo}" --add-topic "$mtopic"
        done
        echo "  -> Done."
        echo ""
    fi

done <<< "$REPOS"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if $JSON_MODE; then
    exit 0
fi

echo ""
echo "======================================================================="
echo "  SUMMARY"
echo "======================================================================="
echo ""
echo "  Total repos audited:            ${TOTAL}"
echo "  Missing description:            ${MISSING_DESC}"
echo "  Missing homepage URL:           ${MISSING_URL}"
echo "  Missing ALL topics:             ${MISSING_TOPICS}"
echo "  Missing mandatory topics:       ${MISSING_MANDATORY_TOPIC}"
echo ""

if [[ ${#REPOS_NO_DESC[@]} -gt 0 ]]; then
    echo "--- Repos missing description (${#REPOS_NO_DESC[@]}) ---"
    for r in "${REPOS_NO_DESC[@]}"; do
        echo "  - $r"
    done
    echo ""
fi

if [[ ${#REPOS_NO_TOPICS[@]} -gt 0 ]]; then
    echo "--- Repos with NO topics at all (${#REPOS_NO_TOPICS[@]}) ---"
    for r in "${REPOS_NO_TOPICS[@]}"; do
        echo "  - $r"
    done
    echo ""
fi

if [[ ${#REPOS_NO_MANDATORY[@]} -gt 0 ]]; then
    echo "--- Repos missing mandatory topics (${#REPOS_NO_MANDATORY[@]}) ---"
    for r in "${REPOS_NO_MANDATORY[@]}"; do
        echo "  - $r"
    done
    echo ""
fi

echo "======================================================================="
echo "  BATCH UPDATE COMMANDS (copy/paste to fix)"
echo "======================================================================="
echo ""
echo "# Add mandatory topics to ALL repos missing them:"
echo "# (Run this script with --fix-topics to do it automatically)"
echo ""

if [[ ${#REPOS_NO_TOPICS[@]} -gt 0 ]]; then
    echo "# -- Repos with zero topics (add mandatory + relevant topics) --"
    for r in "${REPOS_NO_TOPICS[@]}"; do
        echo "gh repo edit ${OWNER}/${r} --add-topic hyperpolymath --add-topic palimpsest"
    done
    echo ""
fi

echo "# -- Set descriptions (fill in the quotes) --"
for r in "${REPOS_NO_DESC[@]+"${REPOS_NO_DESC[@]}"}"; do
    [[ -n "$r" ]] && echo "# gh repo edit ${OWNER}/${r} --description \"TODO: add description\""
done
echo ""

echo "# -- Set homepage URLs --"
echo "# Pattern: https://hyperpolymath.github.io/REPO/ (for GitHub Pages)"
echo "# Pattern: https://REPO.hyperpolymath.dev/ (for custom domains)"
echo "# Example:"
echo "# gh repo edit ${OWNER}/some-repo --homepage \"https://hyperpolymath.github.io/some-repo/\""
echo ""

echo "# -- Add topics to a repo --"
echo "# gh repo edit ${OWNER}/REPO --add-topic TOPIC"
echo "# gh repo edit ${OWNER}/REPO --remove-topic TOPIC"
echo ""

echo "Done. Review the output above and run the suggested commands."
