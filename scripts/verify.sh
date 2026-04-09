#!/bin/bash

# Source shared configuration
if [ -f "/var/mnt/eclipse/repos/git-scripts/config/repos.config" ]; then
    source "/var/mnt/eclipse/repos/git-scripts/config/repos.config"
else
    echo "Error: Configuration file not found: /var/mnt/eclipse/repos/git-scripts/config/repos.config" >&2
    exit 1
fi

echo "Repository | Local Commit | Remote Commit | Match?"
echo "---|---|---|---"
for REPO in "${REPOS[@]}"; do
    cd "$BASE_DIR/$REPO" || continue
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    LOCAL_MSG=$(git log -1 --pretty=format:"%s")
    REMOTE_MSG=$(git log -1 --pretty=format:"%s" origin/"$BRANCH" 2>/dev/null || echo "N/A")
    MATCH="No"
    if [[ "$LOCAL_MSG" == "$REMOTE_MSG" ]]; then MATCH="Yes"; fi
    echo "$REPO | $LOCAL_MSG | $REMOTE_MSG | $MATCH"
done
