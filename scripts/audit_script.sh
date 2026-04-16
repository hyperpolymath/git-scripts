#!/bin/bash
set -uo pipefail
TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$TOKEN" ]; then
    echo "GITHUB_TOKEN is required" >&2
    exit 1
fi
REPOS_DIR="${REPOS_DIR:-/var/mnt/eclipse/repos}"
CONFIG_FILE="$REPOS_DIR/gitleaks_config.toml"
GLOBAL_IGNORE="$REPOS_DIR/global_gitleaksignore"

# --- Ownership safety guard ---
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ownership_guard.sh
source "${_SCRIPT_DIR}/lib/ownership_guard.sh"

# Create global ignore from boj-server
cp "$REPOS_DIR/boj-server/.gitleaksignore" "$GLOBAL_IGNORE" 2>/dev/null || touch "$GLOBAL_IGNORE"

echo "| Repo | Owner | Gitleaks Findings | Dependabot Alerts (Crit/High) | Status |"
echo "| --- | --- | --- | --- | --- |"

# Filter directories and iterate
for repo_path in "$REPOS_DIR"/*/; do
    repo_name=$(basename "$repo_path")

    [ -d "$repo_path" ] || continue
    [ "$repo_name" = ".git" ] && continue
    [ "$repo_name" = ".gemini" ] && continue
    [ "$repo_name" = ".claude" ] && continue
    [ "$repo_name" = "scripts" ] && continue
    [ "$repo_name" = "audit_script.sh" ] && continue

    # --- Ownership filter ---
    # Determine the owner from the repo's origin remote and skip anything
    # outside the configured allowlist.
    repo_owner="$(repo_owner_from_remote "$repo_path" 2>/dev/null || true)"
    if [ -z "${repo_owner}" ] || ! owner_allowed "${repo_owner}"; then
        echo "| $repo_name | ${repo_owner:-unknown} | - | - | SKIPPED (owner not allowed) |"
        continue
    fi

    # Gitleaks Scan
    REPORT_FILE=$(mktemp)
    # Using the user requested flags: --source . --no-git --verbose
    # We add config and ignore path
    gitleaks detect --source "$repo_path" --no-git --config "$CONFIG_FILE" --gitleaks-ignore-path "$GLOBAL_IGNORE" --report-path "$REPORT_FILE" --report-format json > /dev/null 2>&1
    GITLEAKS_COUNT=$(grep -c "Fingerprint" "$REPORT_FILE" || echo 0)

    # Dependabot Audit (uses the actual owner derived from the repo)
    ENCODED_NAME=$(echo "$repo_name" | sed 's/ /%20/g')
    ALERTS_JSON=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/${repo_owner}/$ENCODED_NAME/dependabot/alerts?state=open")
    
    if echo "$ALERTS_JSON" | jq -e '.message == "Not Found" or .message == "Moved Permanently" or .message == "Bad credentials"' > /dev/null 2>&1 || [ -z "$ALERTS_JSON" ]; then
        DEPENDABOT_COUNT="N/A"
    elif [ "$ALERTS_JSON" = "[]" ]; then
        DEPENDABOT_COUNT="0/0"
    else
        # Count Critical and High alerts using jq
        CRITICAL_COUNT=$(echo "$ALERTS_JSON" | jq -r '[.[] | select(.security_advisory.severity == "critical")] | length' 2>/dev/null || echo 0)
        HIGH_COUNT=$(echo "$ALERTS_JSON" | jq -r '[.[] | select(.security_advisory.severity == "high")] | length' 2>/dev/null || echo 0)
        DEPENDABOT_COUNT="$CRITICAL_COUNT/$HIGH_COUNT"
    fi
    
    # Determine Status
    STATUS="OK"
    if [ "$GITLEAKS_COUNT" -gt 0 ]; then
        STATUS="Action Required (Gitleaks: $GITLEAKS_COUNT)"
    elif [ "$DEPENDABOT_COUNT" != "N/A" ] && [ "$DEPENDABOT_COUNT" != "0/0" ]; then
        CRITICAL=$(echo "$DEPENDABOT_COUNT" | cut -d/ -f1)
        HIGH=$(echo "$DEPENDABOT_COUNT" | cut -d/ -f2)
        if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
            STATUS="Action Required (Dependabot: $DEPENDABOT_COUNT)"
        fi
    fi

    echo "| $repo_name | $repo_owner | $GITLEAKS_COUNT | $DEPENDABOT_COUNT | $STATUS |"

    rm "$REPORT_FILE"
done
