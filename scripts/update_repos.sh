#!/bin/bash

# Source shared configuration
if [ -f "/var/mnt/eclipse/repos/git-scripts/config/repos.config" ]; then
    source "/var/mnt/eclipse/repos/git-scripts/config/repos.config"
else
    echo "Error: Configuration file not found: /var/mnt/eclipse/repos/git-scripts/config/repos.config" >&2
    exit 1
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
    
    # 2. Force-Push
    echo "Pusing $REPO..."
    if ! git push --force 2>&1 | tee /tmp/git_push_out; then
        # 3. Upstream Check
        if grep -q "has no upstream branch" /tmp/git_push_out || grep -q "The current branch .* has no upstream branch" /tmp/git_push_out; then
            BRANCH=$(git rev-parse --abbrev-ref HEAD)
            echo "No upstream set for $REPO. Setting upstream origin $BRANCH..."
            if ! git push --set-upstream origin "$BRANCH" --force; then
                FAILURES+=("$REPO (push failed even with upstream)")
            fi
        else
            FAILURES+=("$REPO (push failed: $(cat /tmp/git_push_out | head -n 1))")
        fi
    fi
    
    # 4. Verification
    LATEST_LOCAL=$(git log -1 --pretty=format:"%s")
    # Fetch to compare with remote
    git fetch origin $(git rev-parse --abbrev-ref HEAD) &>/dev/null
    LATEST_REMOTE=$(git log -1 --pretty=format:"%s" origin/$(git rev-parse --abbrev-ref HEAD) 2>/dev/null)
    
    echo "Local: $LATEST_LOCAL"
    echo "Remote: $LATEST_REMOTE"
    
    if [[ "$LATEST_LOCAL" == "chore: RSR sync"* ]] && [[ "$LATEST_LOCAL" == "$LATEST_REMOTE" ]]; then
        echo "Verification successful for $REPO"
    else
        echo "Verification: Local and Remote might differ or commit message mismatch for $REPO"
        # We don't mark as failure if it's just a message mismatch unless it failed to push
    fi
    echo "-----------------------------------"
done

echo "Persistent Failures:"
for FAIL in "${FAILURES[@]}"; do
    echo "- $FAIL"
done
