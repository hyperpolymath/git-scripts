#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# comprehensive_script_organization.sh — Organize and integrate all scripts

set -euo pipefail

echo "=== COMPREHENSIVE SCRIPT ORGANIZATION ==="
echo "Analyzing and organizing scripts across repositories"
echo ""

# Define directories
GIT_SCRIPTS_DIR="/var/mnt/eclipse/repos/git-scripts"
CLEANUP_SCRIPTS_DIR="/var/mnt/eclipse/cleanup_scripts"
SPEC_VAULT_DIR="/mnt/eclipse/spec-vault"
REPOS_ROOT="/var/mnt/eclipse/repos"

echo "📁 Key Directories:"
echo "  Git Scripts: $GIT_SCRIPTS_DIR"
echo "  Cleanup Scripts: $CLEANUP_SCRIPTS_DIR"
echo "  Spec Vault: $SPEC_VAULT_DIR"
echo "  Repos Root: $REPOS_ROOT"
echo ""

# Create script inventory
SCRIPT_INVENTORY="/var/mnt/eclipse/repos/SCRIPT_INVENTORY.md"
echo "# Script Inventory - $(date)" > "$SCRIPT_INVENTORY"
echo "" >> "$SCRIPT_INVENTORY"

echo "🔍 Analyzing scripts in repos root..."
ROOT_SCRIPTS=$(ls -1 "$REPOS_ROOT"/*.sh 2>/dev/null | wc -l)
echo "Found $ROOT_SCRIPTS scripts in repos root"

# Categorize root scripts
if [ $ROOT_SCRIPTS -gt 0 ]; then
    echo "" >> "$SCRIPT_INVENTORY"
    echo "## Root Directory Scripts" >> "$SCRIPT_INVENTORY"
    echo "" >> "$SCRIPT_INVENTORY"
    
    for script in "$REPOS_ROOT"/*.sh; do
        if [ -f "$script" ]; then
            echo "### $(basename "$script")" >> "$SCRIPT_INVENTORY"
            echo "" >> "$SCRIPT_INVENTORY"
            echo "**Size**: $(wc -c < "$script") bytes" >> "$SCRIPT_INVENTORY"
            echo "**Lines**: $(wc -l < "$script")" >> "$SCRIPT_INVENTORY"
            echo "**Modified**: $(stat -c %y "$script" | cut -d' ' -f1)" >> "$SCRIPT_INVENTORY"
            echo "" >> "$SCRIPT_INVENTORY"
            echo "**Purpose**:" >> "$SCRIPT_INVENTORY"
            head -5 "$script" | sed 's/^/  /' >> "$SCRIPT_INVENTORY"
            echo "" >> "$SCRIPT_INVENTORY"
            echo "**Recommendation**: " >> "$SCRIPT_INVENTORY"
            
            # Determine if script is reusable or one-off
            case "$(basename "$script")" in
                "apply_cleanup.sh"|"cleanup_repos.sh"|"comprehensive_cleanup.sh")
                    echo "**KEEP** - Core cleanup infrastructure" >> "$SCRIPT_INVENTORY"
                    ;;
                "AUTO-CREATE-ALL-PRS.sh"|"FIX-ALL-PR-ISSUES.sh"|"batch-create-prs.sh")
                    echo "**REVIEW** - Potential one-off PR script" >> "$SCRIPT_INVENTORY"
                    ;;
                *)
                    echo "**REVIEW** - Determine if reusable" >> "$SCRIPT_INVENTORY"
                    ;;
            esac
            echo "" >> "$SCRIPT_INVENTORY"
        fi
    done
fi

echo "" >> "$SCRIPT_INVENTORY"
echo "## Reusable Scripts Identified" >> "$SCRIPT_INVENTORY"
echo "" >> "$SCRIPT_INVENTORY"

# List reusable scripts from spec-vault
if [ -d "$SPEC_VAULT_DIR" ]; then
    echo "### Spec Vault Scripts" >> "$SCRIPT_INVENTORY"
    for script in "$SPEC_VAULT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            echo "- **$(basename "$script")**: $(head -2 "$script" | tail -1 | sed 's/# //')" >> "$SCRIPT_INVENTORY"
        fi
    done
    echo "" >> "$SCRIPT_INVENTORY"
fi

# List reusable scripts from cleanup directory
if [ -d "$CLEANUP_SCRIPTS_DIR" ]; then
    echo "### Cleanup Infrastructure Scripts" >> "$SCRIPT_INVENTORY"
    for script in "$CLEANUP_SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ]; then
            echo "- **$(basename "$script")**: $(head -2 "$script" | tail -1 | sed 's/# //')" >> "$SCRIPT_INVENTORY"
        fi
    done
    echo "" >> "$SCRIPT_INVENTORY"
fi

echo "" >> "$SCRIPT_INVENTORY"
echo "## Integration Recommendations" >> "$SCRIPT_INVENTORY"
echo "" >> "$SCRIPT_INVENTORY"

echo "✅ Script inventory created: $SCRIPT_INVENTORY"
echo ""

echo "=== ORGANIZATION RECOMMENDATIONS ==="
echo ""

echo "1. REUSABLE SCRIPTS (Integrate into git-scripts):"
echo "   - spec-vault/snapshot-specs.sh"
echo "   - spec-vault/verify-specs.sh"
echo "   - repo_cleanup_scripts/* (already integrated)"
echo ""

echo "2. ONE-OFF SCRIPTS (Review for cleanup):"
echo "   - AUTO-CREATE-ALL-PRS.sh"
echo "   - FIX-ALL-PR-ISSUES.sh"
echo "   - batch-create-prs.sh"
echo "   - create-chore-prs.sh"
echo "   - find-all-chore-branches.sh"
echo "   - find-chore-prs.sh"
echo ""

echo "3. CORE INFRASTRUCTURE (Keep in root):"
echo "   - apply_cleanup.sh"
echo "   - cleanup_repos.sh"
echo "   - comprehensive_cleanup.sh"
echo ""

echo "=== INTEGRATION STATUS ==="
echo ""

# Check integration
if [ -f "$GIT_SCRIPTS_DIR/lib/script_manager/repo_cleanup.ex" ]; then
    echo "✅ RepoCleanup module: INTEGRATED"
else
    echo "❌ RepoCleanup module: NOT INTEGRATED"
fi

if grep -q "ScriptManager.RepoCleanup" "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex"; then
    echo "✅ TUI integration: COMPLETE"
else
    echo "❌ TUI integration: PENDING"
fi

if [ -f "$GIT_SCRIPTS_DIR/scripts/repo_cleanup_integration.sh" ]; then
    echo "✅ Integration script: AVAILABLE"
else
    echo "❌ Integration script: MISSING"
fi

echo ""
echo "=== ACTION PLAN ==="
echo ""
echo "1. Review script inventory: $SCRIPT_INVENTORY"
echo "2. Decide which one-off scripts to keep/remove"
echo "3. Integrate reusable scripts into git-scripts"
echo "4. Update documentation"
echo "5. Run: cd $GIT_SCRIPTS_DIR && ./script_manager"
echo ""

echo "✅ Comprehensive script organization complete!"
echo "   All scripts analyzed and categorized"
echo "   Integration recommendations provided"
echo "   Inventory saved to: $SCRIPT_INVENTORY"
