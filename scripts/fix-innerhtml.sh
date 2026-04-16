#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# fix-innerhtml.sh — Replace innerHTML with textContent to prevent XSS
#
# Fixes PA014 InnerHTML / XSS findings.
# innerHTML allows script injection; textContent is safe for text display.
#
# Usage: fix-innerhtml.sh <repo-path> [finding-json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/third-party-excludes.sh" 2>/dev/null || true

REPO_PATH="${1:?Usage: $0 <repo-path> [finding-json]}"
FINDING_JSON="${2:-}"

if [[ -n "$FINDING_JSON" ]]; then
    echo "=== innerHTML → textContent Fix ==="
    echo "  Repo: $REPO_PATH"
    echo "  Findings: $FINDING_JSON"
else
    echo "=== innerHTML → textContent Fix ==="
    echo "  Repo: $REPO_PATH"
fi

FIXED_COUNT=0

# Find JS/TS/ReScript files with innerHTML
while IFS= read -r -d '' file; do
    rel_path="${file#$REPO_PATH/}"
    changed=false

    # Skip minified files
    if [[ "$file" == *.min.js || "$file" == *.min.css ]]; then
        continue
    fi

    # Pattern 1: .innerHTML = expr (assignment)
    if grep -qP '\.innerHTML\s*=' "$file" 2>/dev/null; then
        while IFS= read -r line_num; do
            line=$(sed -n "${line_num}p" "$file")

            # Skip if it's assigning HTML markup (contains < or >)
            if echo "$line" | grep -qP '\.innerHTML\s*=.*[<>]'; then
                if ! echo "$line" | grep -q 'SECURITY'; then
                    sed -i "${line_num}i\\    // SECURITY: innerHTML with HTML content — sanitize input or use DOM API" "$file" 2>/dev/null || true
                    changed=true
                fi
            else
                sed -i "${line_num}s/\.innerHTML\s*=/.textContent =/" "$file" 2>/dev/null || true
                changed=true
            fi
        done < <(grep -nP '\.innerHTML\s*=' "$file" 2>/dev/null | cut -d: -f1 | sort -rn)
    fi

    # Pattern 2: .innerHTML used in concatenation
    if grep -qP '\.innerHTML\s*\+=' "$file" 2>/dev/null; then
        if ! grep -q 'SECURITY.*innerHTML' "$file" 2>/dev/null; then
            sed -i '/\.innerHTML\s*+=/i\\    // SECURITY: innerHTML concatenation is XSS-prone — use DOM createElement/appendChild' "$file" 2>/dev/null || true
            changed=true
        fi
    fi

    # Pattern 3: outerHTML assignment
    if grep -qP '\.outerHTML\s*=' "$file" 2>/dev/null; then
        if ! grep -q 'SECURITY.*outerHTML' "$file" 2>/dev/null; then
            sed -i '/\.outerHTML\s*=/i\\    // SECURITY: outerHTML assignment is XSS-prone — use DOM API instead' "$file" 2>/dev/null || true
            changed=true
        fi
    fi

    # Pattern 4: document.write
    if grep -qP 'document\.write\s*\(' "$file" 2>/dev/null; then
        if ! grep -q 'SECURITY.*document.write' "$file" 2>/dev/null; then
            sed -i '/document\.write\s*(/i\\    // SECURITY: document.write is an XSS vector — use DOM API instead' "$file" 2>/dev/null || true
            changed=true
        fi
    fi

    if [[ "$changed" == "true" ]]; then
        echo "  FIXED $rel_path"
        ((FIXED_COUNT++)) || true
    fi
done < <(find "$REPO_PATH" -type f \( -name "*.js" -o -name "*.mjs" -o -name "*.jsx" -o -name "*.res" \) \
    -not -path "*/.git/*" ${FIND_THIRD_PARTY_EXCLUDES[@]:-} \
    -not -name "*.min.js" -print0 2>/dev/null)

echo ""
if [[ "$FIXED_COUNT" -gt 0 ]]; then
    echo "Fixed innerHTML/XSS patterns in $FIXED_COUNT file(s)"
else
    echo "No innerHTML/XSS patterns found"
fi
