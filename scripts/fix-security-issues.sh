#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# fix-security-issues.sh — Automated security remediation for Rust and JavaScript
#
# Runs both unwrap→expect and innerHTML→textContent fixes sequentially.
# Designed for integration with CI/CD pipelines or manual security audits.
#
# Usage: fix-security-issues.sh <repo-path> [finding-json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

REPO_PATH="${1:?Usage: $0 <repo-path> [finding-json]}"
FINDING_JSON="${2:-}"

echo "=== Security Issue Remediation ==="
echo "  Repository: $REPO_PATH"
if [[ -n "$FINDING_JSON" ]]; then
    echo "  Findings: $FINDING_JSON"
fi
echo ""

# Run Rust unwrap fixes
echo "Step 1/2: Fixing Rust .unwrap() calls..."
"$SCRIPT_DIR/fix-unwrap-to-match.sh" "$REPO_PATH" "$FINDING_JSON"
echo ""

# Run JavaScript innerHTML fixes
echo "Step 2/2: Fixing JavaScript innerHTML usage..."
"$SCRIPT_DIR/fix-innerhtml.sh" "$REPO_PATH" "$FINDING_JSON"
echo ""

echo "=== Security Remediation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Review changes with: git diff"
echo "  2. Test affected functionality"
echo "  3. Commit changes with descriptive message"
echo "  4. Consider adding these scripts to your CI/CD pipeline"
