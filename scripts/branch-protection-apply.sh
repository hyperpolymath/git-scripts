#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# branch-protection-apply.sh
# Applies strict branch protection rulesets to all hyperpolymath GitHub repos
# using the newer rulesets API (not the legacy branch protection API).
#
# Ruleset enforces:
#   - Require signed commits
#   - Require linear history
#   - Block force pushes (non_fast_forward)
#   - Block branch deletions
#   - Require status checks to pass (if any exist)
#   - CodeQL code scanning (errors threshold)
#
# Bypass actors (matching rsr-template-repo pattern):
#   - RepositoryRole 5 (admin/maintain)
#   - Integration 29110  (rhodibot or similar)
#   - Integration 1143301
#   - Integration 1236702
#
# Usage: ./branch-protection-apply.sh [--dry-run]
#
# Author: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OWNER="hyperpolymath"
RULESET_NAME="Base"
DRY_RUN=false
LIMIT=600

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN] No changes will be made."
fi

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------

total=0
skipped_archived=0
skipped_existing=0
applied=0
failed=0

# ---------------------------------------------------------------------------
# Fetch all repos (name, default branch, archived status)
# ---------------------------------------------------------------------------

echo "Fetching repo list for ${OWNER} (limit ${LIMIT})..."

repos_json="$(gh repo list "${OWNER}" \
    --limit "${LIMIT}" \
    --json name,defaultBranchRef,isArchived \
    --jq '.[] | @base64')"

repo_count="$(echo "${repos_json}" | wc -l)"
echo "Found ${repo_count} repos."
echo "========================================="

# ---------------------------------------------------------------------------
# Ruleset payload template (uses jq to interpolate the default branch)
# ---------------------------------------------------------------------------

build_payload() {
    local default_branch="$1"

    cat <<ENDJSON
{
  "name": "${RULESET_NAME}",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    },
    {
      "actor_id": 29110,
      "actor_type": "Integration",
      "bypass_mode": "always"
    },
    {
      "actor_id": 1143301,
      "actor_type": "Integration",
      "bypass_mode": "always"
    },
    {
      "actor_id": 1236702,
      "actor_type": "Integration",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "required_signatures"
    },
    {
      "type": "required_deployments",
      "parameters": {
        "required_deployment_environments": []
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": true,
        "required_status_checks": []
      }
    },
    {
      "type": "code_scanning",
      "parameters": {
        "code_scanning_tools": [
          {
            "tool": "CodeQL",
            "alerts_threshold": "errors",
            "security_alerts_threshold": "high_or_higher"
          }
        ]
      }
    }
  ]
}
ENDJSON
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

for row in ${repos_json}; do
    total=$((total + 1))

    # Decode the base64 row
    decoded="$(echo "${row}" | base64 --decode)"

    repo_name="$(echo "${decoded}" | jq -r '.name')"
    is_archived="$(echo "${decoded}" | jq -r '.isArchived')"
    default_branch="$(echo "${decoded}" | jq -r '.defaultBranchRef.name // "main"')"

    # Progress prefix
    prefix="[${total}/${repo_count}] ${repo_name}"

    # Skip archived repos
    if [[ "${is_archived}" == "true" ]]; then
        echo "${prefix}: SKIPPED (archived)"
        skipped_archived=$((skipped_archived + 1))
        continue
    fi

    # Check if a ruleset named "Base" already exists
    existing_id="$(gh api "repos/${OWNER}/${repo_name}/rulesets" \
        --jq ".[] | select(.name == \"${RULESET_NAME}\") | .id" 2>/dev/null || true)"

    if [[ -n "${existing_id}" ]]; then
        # Update the existing ruleset instead of creating a duplicate
        if [[ "${DRY_RUN}" == true ]]; then
            echo "${prefix}: WOULD UPDATE existing ruleset #${existing_id} (default branch: ${default_branch})"
            skipped_existing=$((skipped_existing + 1))
        else
            payload="$(build_payload "${default_branch}")"
            if gh api "repos/${OWNER}/${repo_name}/rulesets/${existing_id}" \
                --method PUT \
                --input - <<< "${payload}" > /dev/null 2>&1; then
                echo "${prefix}: UPDATED existing ruleset #${existing_id} (${default_branch})"
                applied=$((applied + 1))
            else
                echo "${prefix}: FAILED to update ruleset #${existing_id}"
                failed=$((failed + 1))
            fi
        fi
        continue
    fi

    # Create new ruleset
    if [[ "${DRY_RUN}" == true ]]; then
        echo "${prefix}: WOULD CREATE ruleset (default branch: ${default_branch})"
        applied=$((applied + 1))
    else
        payload="$(build_payload "${default_branch}")"
        if gh api "repos/${OWNER}/${repo_name}/rulesets" \
            --method POST \
            --input - <<< "${payload}" > /dev/null 2>&1; then
            echo "${prefix}: CREATED ruleset (${default_branch})"
            applied=$((applied + 1))
        else
            echo "${prefix}: FAILED to create ruleset"
            failed=$((failed + 1))
        fi
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "========================================="
echo "SUMMARY"
echo "========================================="
echo "Total repos:        ${total}"
echo "Applied/updated:    ${applied}"
echo "Skipped (archived): ${skipped_archived}"
echo "Skipped (existing): ${skipped_existing}"
echo "Failed:             ${failed}"
echo "========================================="

if [[ "${failed}" -gt 0 ]]; then
    echo "WARNING: ${failed} repos failed. Re-run with output redirected to investigate."
    exit 1
fi

echo "Done."
