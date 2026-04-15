#!/bin/bash

# Source shared configuration
if [ -f "/var/mnt/eclipse/repos/git-scripts/config/repos.config" ]; then
    source "/var/mnt/eclipse/repos/git-scripts/config/repos.config"
else
    # Fallback if source fails or we're running from elsewhere
    BASE_DIR="${REPOS_DIR:-/var/mnt/eclipse/repos}"
fi

if [[ -z "${REPOS:-}" ]]; then
    echo "Warning: REPOS list is empty or not loaded."
    # Attempt to find all repos if list is empty
    mapfile -t REPOS < <(find "$BASE_DIR" -maxdepth 1 -type d -exec test -d "{}/.git" \; -print | xargs -n1 basename)
fi

FAILURES=()

for REPO in "${REPOS[@]}"; do
    REPO_PATH="$BASE_DIR/$REPO"
    echo "Processing $REPO..."
    
    if [ ! -d "$REPO_PATH/.git" ]; then
        echo "Error: $REPO_PATH is not a git repository."
        FAILURES+=("$REPO (not a git repo)")
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
