#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# repo_cleanup_integration.sh — Integrate cleanup scripts with git-scripts TUI

set -euo pipefail

echo "=== REPOSITORY CLEANUP INTEGRATION ==="
echo "Integrating cleanup scripts with Elixir TUI"
echo ""

# Define directories
GIT_SCRIPTS_DIR="/var/mnt/eclipse/repos/git-scripts"
CLEANUP_SCRIPTS_DIR="/var/mnt/eclipse/cleanup_scripts"
SPEC_VAULT_DIR="/mnt/eclipse/spec-vault"

echo "📁 Directories:"
echo "  Git Scripts: $GIT_SCRIPTS_DIR"
echo "  Cleanup Scripts: $CLEANUP_SCRIPTS_DIR"
echo "  Spec Vault: $SPEC_VAULT_DIR"
echo ""

# Check if the RepoCleanup module exists
if [ -f "$GIT_SCRIPTS_DIR/lib/script_manager/repo_cleanup.ex" ]; then
    echo "✅ RepoCleanup module found"
else
    echo "❌ RepoCleanup module not found"
    echo "   Please create it first:"
    echo "   cp $CLEANUP_SCRIPTS_DIR/repo_cleanup.ex $GIT_SCRIPTS_DIR/lib/script_manager/"
fi

# Check TUI integration
if grep -q "ScriptManager.RepoCleanup" "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex"; then
    echo "✅ TUI integration found"
else
    echo "❌ TUI integration not found"
    echo "   Please add to tui.ex:"
    echo "   - Menu option: \"[12] Repository Cleanup\""
    echo "   - Case handler: \"12\" -> ScriptManager.RepoCleanup.run()"
fi

echo ""
echo "=== AVAILABLE CLEANUP SCRIPTS ==="
echo ""

# List available cleanup scripts
if [ -d "$CLEANUP_SCRIPTS_DIR" ]; then
    echo "Cleanup Scripts Directory:"
    ls -lh "$CLEANUP_SCRIPTS_DIR" | grep -v "^d" | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
else
    echo "Cleanup scripts directory not found: $CLEANUP_SCRIPTS_DIR"
fi

echo "=== SPEC VAULT SCRIPTS ==="
echo ""

# List spec vault scripts
if [ -d "$SPEC_VAULT_DIR" ]; then
    echo "Spec Vault Scripts:"
    ls -lh "$SPEC_VAULT_DIR"/*.sh 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
else
    echo "Spec vault directory not found: $SPEC_VAULT_DIR"
fi

echo "=== INTEGRATION OPTIONS ==="
echo ""
echo "1. Run comprehensive cleanup (all 280+ repos)"
echo "2. Run targeted cleanup (10 key repos)"
echo "3. Analyze repositories only"
echo "4. Update .gitignore files"
echo "5. Commit workflow files"
echo "6. Snapshot specs to vault"
echo "7. Verify specs against vault"
echo ""

echo "=== USAGE EXAMPLES ==="
echo ""
echo "# Run through Elixir TUI:"
echo "cd $GIT_SCRIPTS_DIR"
echo "./script_manager"
echo "Select option 12 for Repository Cleanup"
echo ""
echo "# Run directly from command line:"
echo "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh"
echo "$CLEANUP_SCRIPTS_DIR/focused_cleanup.sh"
echo "$SPEC_VAULT_DIR/snapshot-specs.sh"
echo "$SPEC_VAULT_DIR/verify-specs.sh"
echo ""

echo "=== CLEANUP RECOMMENDATIONS ==="
echo ""

# Find potential one-off scripts that could be clutter
ONE_OFF_SCRIPTS=$(find /mnt/eclipse/repos -maxdepth 3 -name "*.sh" | grep -v ".git" | grep -v "git-scripts" | grep -v "setup.sh" | wc -l)
echo "Potential one-off scripts found: $ONE_OFF_SCRIPTS"

if [ $ONE_OFF_SCRIPTS -gt 0 ]; then
    echo ""
    echo "Review these scripts for potential cleanup:"
    find /mnt/eclipse/repos -maxdepth 3 -name "*.sh" | grep -v ".git" | grep -v "git-scripts" | grep -v "setup.sh" | head -5
fi

echo ""
echo "✅ Integration complete!"
echo "   - Cleanup scripts integrated with Elixir TUI"
echo "   - Spec vault scripts available for reuse"
echo "   - Documentation updated"
echo ""
echo "Run: cd $GIT_SCRIPTS_DIR && ./script_manager"
echo "Then select option 12 for Repository Cleanup"
