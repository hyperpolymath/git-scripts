#!/bin/bash
REPOS=("aerie" "ambientops" "Axiom.jl" "boj-server-gemini" "excel-economic-numbers-tool" "explicit-trust-plane" "feedback-o-tron" "filesoup" "fireflag" "flat-mate" "games & trivia" "gitbot-fleet" "hesiod-dns-map" "idaptik" "rescript" "flatracoon" "neural-foundations" "standards" "wordpress-tools")
BASE_DIR="/var$REPOS_DIR"

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
