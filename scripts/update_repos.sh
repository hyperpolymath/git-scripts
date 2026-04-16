#!/bin/bash

# Source shared configuration
if [ -f "/var/mnt/eclipse/repos/git-scripts/config/repos.config" ]; then
    source "/var/mnt/eclipse/repos/git-scripts/config/repos.config"
else
    # Fallback if source fails or we're running from elsewhere
    BASE_DIR="${REPOS_DIR:-/var/mnt/eclipse/repos}"
fi

# --- Ownership safety guard ---
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ownership_guard.sh
source "${_SCRIPT_DIR}/lib/ownership_guard.sh"

if [[ -z "${REPOS:-}" ]]; then
    echo "Warning: REPOS list is empty or not loaded."
    # Attempt to find all repos if list is empty
    mapfile -t REPOS < <(find "$BASE_DIR" -maxdepth 1 -type d -exec test -d "{}/.git" \; -print | xargs -n1 basename)
fi

FAILURES=()
SKIPPED_OWNERSHIP=()

for REPO in "${REPOS[@]}"; do
    REPO_PATH="$BASE_DIR/$REPO"
    echo "Processing $REPO..."

    if [ ! -d "$REPO_PATH/.git" ]; then
        echo "Error: $REPO_PATH is not a git repository."
        FAILURES+=("$REPO (not a git repo)")
        continue
    fi

    # --- Per-repo ownership filter (refuse to push to foreign owners) ---
    repo_owner="$(repo_owner_from_remote "$REPO_PATH" 2>/dev/null || true)"
    if [ -z "${repo_owner}" ]; then
        echo "Skipping $REPO: no GitHub origin remote (cannot verify owner)."
        SKIPPED_OWNERSHIP+=("$REPO (no github origin)")
        continue
    fi
    if ! owner_allowed "${repo_owner}"; then
        echo "Skipping $REPO: owner '${repo_owner}' is not in the allowlist."
        SKIPPED_OWNERSHIP+=("$REPO (owner=${repo_owner})")
        continue
    fi

    cd "$REPO_PATH" || continue
    
    # 0. Sync from remote first (Hiccup prevention)
    git fetch --all --prune --quiet
    
    # 1. Uncommitted Resolution
    for COMMIT_REPO in "${COMMIT_REPOS[@]}"; do
        if [ "$REPO" == "$COMMIT_REPO" ]; then
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                git commit -m "chore: RSR sync and mass repository update" || echo "Commit failed for $REPO (maybe nothing to commit?)"
            else
                echo "Nothing to commit in $REPO"
            fi
        fi
    done
    
    # 2. Negotiate hiccups (rebase if behind)
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
        BEHIND=$(git rev-list --count "$BRANCH..origin/$BRANCH")
        if [ "$BEHIND" -gt 0 ]; then
            echo "$REPO is behind origin/$BRANCH by $BEHIND commits. Attempting rebase..."
            if ! git rebase "origin/$BRANCH"; then
                echo "Rebase failed for $REPO. Aborting."
                git rebase --abort
                FAILURES+=("$REPO (rebase conflict)")
                continue
            fi
        fi
    fi

    # 3. Push
    echo "Pushing $REPO..."
    # Use --force-with-lease for safer negotiation if branch protection is off, 
    # or just normal push if we just rebased.
    if ! git push --force-with-lease 2>&1 | tee /tmp/git_push_out; then
        # 4. Upstream Check
        if grep -q "has no upstream branch" /tmp/git_push_out || grep -q "The current branch .* has no upstream branch" /tmp/git_push_out; then
            echo "No upstream set for $REPO. Setting upstream origin $BRANCH..."
            if ! git push --set-upstream origin "$BRANCH"; then
                FAILURES+=("$REPO (push failed even with upstream)")
            fi
        else
            FAIL_MSG=$(cat /tmp/git_push_out | head -n 1)
            echo "Push failed for $REPO: $FAIL_MSG"
            FAILURES+=("$REPO (push failed: $FAIL_MSG)")
        fi
    fi
    
    # 5. Verification
    LATEST_LOCAL=$(git log -1 --pretty=format:"%s")
    # Latest remote already fetched
    LATEST_REMOTE=$(git log -1 --pretty=format:"%s" "origin/$BRANCH" 2>/dev/null || echo "NONE")
    
    echo "Local: $LATEST_LOCAL"
    echo "Remote: $LATEST_REMOTE"
    
    if [[ "$LATEST_LOCAL" == "$LATEST_REMOTE" ]]; then
        echo "Verification successful for $REPO"
    else
        echo "Verification: Local and Remote might differ for $REPO"
    fi
    echo "-----------------------------------"
done

echo "Persistent Failures:"
for FAIL in "${FAILURES[@]}"; do
    echo "- $FAIL"
done

if [ "${#SKIPPED_OWNERSHIP[@]}" -gt 0 ]; then
    echo ""
    echo "Skipped (ownership guard):"
    for SKIP in "${SKIPPED_OWNERSHIP[@]}"; do
        echo "- $SKIP"
    done
fi
