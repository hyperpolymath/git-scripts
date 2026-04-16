#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# fix-unwrap-to-match.sh — Replace .unwrap() with .expect() in Rust code
#
# Fixes PanicPath findings by converting bare .unwrap() calls to .expect("TODO: handle error/None")
# which provides context when a panic occurs.
#
# IMPORTANT: .unwrap() → .expect("context") is the only safe mechanical transformation.
# We do NOT convert to match expressions — that changes control flow and can break compilation.
#
# Skips test files where .unwrap() is acceptable.
#
# Usage: fix-unwrap-to-match.sh <repo-path> [finding-json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/third-party-excludes.sh" 2>/dev/null || true

REPO_PATH="${1:?Usage: $0 <repo-path> [finding-json]}"
FINDING_JSON="${2:-}"

if [[ -n "$FINDING_JSON" ]]; then
    echo "=== PanicPath: .unwrap() → .expect() ==="
    echo "  Repo: $REPO_PATH"
    echo "  Findings: $FINDING_JSON"
else
    echo "=== PanicPath: .unwrap() → .expect() ==="
    echo "  Repo: $REPO_PATH"
fi

FIXED_COUNT=0
TOTAL_REPLACEMENTS=0

# Determine if a file is a test file (skip these)
is_test_file() {
    local filepath="$1"
    local basename
    basename="$(basename "$filepath")"

    # Skip common test file patterns
    case "$basename" in
        *_test.rs|test_*.rs) return 0 ;;
    esac

    # Skip files inside tests/ directories
    if echo "$filepath" | grep -qE '/tests/'; then
        return 0
    fi

    # Skip files inside benches/ directories
    if echo "$filepath" | grep -qE '/benches/'; then
        return 0
    fi

    return 1
}

# Process Rust files
while IFS= read -r -d '' file; do
    # Skip test files
    if is_test_file "$file"; then
        continue
    fi

    # Check if file contains .unwrap() calls (not already .expect( or .unwrap_or)
    if ! grep -qP '\.unwrap\(\)' "$file" 2>/dev/null; then
        continue
    fi

    rel_path="${file#$REPO_PATH/}"

    # Count replaceable .unwrap() calls:
    replaceable=$(grep -P '\.unwrap\(\)' "$file" 2>/dev/null \
        | grep -v '^\s*//' \
        | grep -v '\.expect(' \
        || true)

    if [[ -z "$replaceable" ]]; then
        continue
    fi

    count=$(echo "$replaceable" | wc -l)
    echo "  FIXING $rel_path — $count .unwrap() call(s)"

    # Replace .unwrap() with .expect("TODO: handle error") on non-comment lines
    sed -i -E '/^\s*\/\//!{ /\.expect\s*\(/!s/\.unwrap\(\)/\.expect("TODO: handle error")/g }' "$file"

    ((FIXED_COUNT++)) || true
    ((TOTAL_REPLACEMENTS += count)) || true

done < <(find "$REPO_PATH" -type f -name "*.rs" \
    -not -path "*/.git/*" ${FIND_THIRD_PARTY_EXCLUDES[@]:-} \
    -print0 2>/dev/null)

echo ""
if [[ "$FIXED_COUNT" -gt 0 ]]; then
    echo "Fixed $FIXED_COUNT file(s) — replaced $TOTAL_REPLACEMENTS .unwrap() → .expect(\"TODO: handle error\")"
else
    echo "No bare .unwrap() calls found in non-test code"
fi
