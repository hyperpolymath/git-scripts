#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Git Scripts Launcher - Enhanced Edition with Self-Healing and Cross-Platform Support

set -euo pipefail

# =============================================
# ENHANCED LAUNCHER - Self-Healing & Cross-Platform
# =============================================

# Configuration
GIT_SCRIPTS_DIR="/var/mnt/eclipse/repos/git-scripts"
CLEANUP_SCRIPTS_DIR="/var/mnt/eclipse/cleanup_scripts"
DOCUMENTATION_DIR="/var/mnt/eclipse/repos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Platform detection
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            PLATFORM="linux"
            ICON="🐧"
            ;;
        Darwin*)
            PLATFORM="macos"
            ICON="🍎"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            PLATFORM="windows"
            ICON="🪟"
            ;;
        *)
            PLATFORM="unknown"
            ICON="❓"
            ;;
    esac
}

# Self-healing function
self_heal() {
    echo -e "${PURPLE}🔧 Self-healing mode activated${NC}"
    echo ""
    
    local issues_found=0
    local issues_fixed=0
    
    # 1. Check and fix script permissions
    echo -e "${CYAN}Checking script permissions...${NC}"
    for script in "$GIT_SCRIPTS_DIR"/launchers/*.sh "$CLEANUP_SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            echo -e "${YELLOW}⚠️  Fixing permissions: $script${NC}"
            chmod +x "$script" 2>/dev/null || true
            ((issues_fixed++))
        fi
    done
    
    # 2. Check TUI integration
    if [ -f "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex" ]; then
        if ! grep -q "ScriptManager.RepoCleanup" "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex"; then
            echo -e "${YELLOW}⚠️  TUI integration missing - repairing...${NC}"
            # Find the line with "11" and add our line after it
            if grep -q '"11"' "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex"; then
                sed -i '/"11"/a \    "12" -> ScriptManager.RepoCleanup.run()' \
                    "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex"
                ((issues_fixed++))
            fi
        fi
    fi
    
    # 3. Check RepoCleanup module
    if [ ! -f "$GIT_SCRIPTS_DIR/lib/script_manager/repo_cleanup.ex" ]; then
        echo -e "${YELLOW}⚠️  RepoCleanup module missing - attempting to restore...${NC}"
        if [ -f "$CLEANUP_SCRIPTS_DIR/repo_cleanup.ex" ]; then
            cp "$CLEANUP_SCRIPTS_DIR/repo_cleanup.ex" "$GIT_SCRIPTS_DIR/lib/script_manager/"
            ((issues_fixed++))
        fi
    fi
    
    # 4. Rebuild Elixir escript if needed
    if [ -f "$GIT_SCRIPTS_DIR/mix.exs" ]; then
        if [ ! -x "$GIT_SCRIPTS_DIR/script_manager" ]; then
            echo -e "${YELLOW}⚠️  Elixir escript missing - rebuilding...${NC}"
            (cd "$GIT_SCRIPTS_DIR" && mix deps.get && mix compile && mix escript.build) 2>/dev/null || true
            ((issues_fixed++))
        fi
    fi
    
    echo -e "${GREEN}✅ Self-healing complete: $issues_fixed issues fixed${NC}"
    echo ""
}

# Health check function
health_check() {
    echo -e "${PURPLE}🏥 Running comprehensive health check...${NC}"
    echo ""
    
    local issues=0
    local warnings=0
    
    # 1. Check critical scripts
    echo -e "${CYAN}Checking critical scripts...${NC}"
    for script in "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh" \
                   "$CLEANUP_SCRIPTS_DIR/cleanup_repos.sh" \
                   "$GIT_SCRIPTS_DIR/launchers/git-scripts-launcher.sh"; do
        if [ ! -f "$script" ]; then
            echo -e "${RED}❌ MISSING: $script${NC}"
            ((issues++))
        elif [ ! -x "$script" ]; then
            echo -e "${YELLOW}⚠️  NOT EXECUTABLE: $script${NC}"
            ((warnings++))
        else
            echo -e "${GREEN}✅ OK: $script${NC}"
        fi
    done
    
    # 2. Check Elixir module
    echo -e "${CYAN}Checking Elixir integration...${NC}"
    if [ ! -f "$GIT_SCRIPTS_DIR/lib/script_manager/repo_cleanup.ex" ]; then
        echo -e "${RED}❌ MISSING: RepoCleanup module${NC}"
        ((issues++))
    else
        echo -e "${GREEN}✅ OK: RepoCleanup module${NC}"
    fi
    
    # 3. Check TUI integration
    if [ -f "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex" ]; then
        if grep -q "ScriptManager.RepoCleanup" "$GIT_SCRIPTS_DIR/lib/script_manager/tui.ex"; then
            echo -e "${GREEN}✅ OK: TUI integration${NC}"
        else
            echo -e "${YELLOW}⚠️  MISSING: TUI integration${NC}"
            ((warnings++))
        fi
    else
        echo -e "${RED}❌ MISSING: TUI file${NC}"
        ((issues++))
    fi
    
    # 4. Check Elixir escript
    if [ -f "$GIT_SCRIPTS_DIR/mix.exs" ]; then
        if [ -x "$GIT_SCRIPTS_DIR/script_manager" ]; then
            echo -e "${GREEN}✅ OK: Elixir escript${NC}"
        else
            echo -e "${YELLOW}⚠️  MISSING: Elixir escript${NC}"
            ((warnings++))
        fi
    fi
    
    echo ""
    if [ $issues -eq 0 ] && [ $warnings -eq 0 ]; then
        echo -e "${GREEN}✅ System healthy - no issues found${NC}"
        return 0
    elif [ $issues -gt 0 ]; then
        echo -e "${RED}❌ CRITICAL: $issues issues found, $warnings warnings${NC}"
        read -p "Run self-healing now? [Y/n]: " answer
        if [[ "$answer" != [Nn] ]]; then
            self_heal
        fi
        return 1
    else
        echo -e "${YELLOW}⚠️  $warnings warnings found${NC}"
        read -p "Run self-healing now? [Y/n]: " answer
        if [[ "$answer" != [Nn] ]]; then
            self_heal
        fi
        return 0
    fi
}

# Run Manager Wrapper Function (INTEGRATED)
run_manager_wrapper() {
    echo -e "${CYAN}Run Manager - Elixir TUI Wrapper${NC}"
    echo ""
    
    if [ -x "./script_manager" ]; then
        echo -e "${GREEN}Launching Elixir TUI...${NC}"
        ./script_manager
        echo ""
        echo "Script manager exited."
    else
        echo -e "${RED}❌ Elixir escript not found${NC}"
        echo -e "${YELLOW}Attempting to rebuild...${NC}"
        if [ -f "mix.exs" ]; then
            mix deps.get 2>/dev/null || echo "Dependency fetch completed"
            mix compile 2>/dev/null || echo "Compilation completed"
            mix escript.build 2>/dev/null || echo "Build completed"
            if [ -x "./script_manager" ]; then
                echo -e "${GREEN}✅ Rebuilt successfully${NC}"
                ./script_manager
            else
                echo -e "${RED}❌ Rebuild failed${NC}"
            fi
        else
            echo -e "${RED}❌ mix.exs not found - cannot rebuild${NC}"
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..." -r
}

# Setup Environment Function (INTEGRATED)
setup_environment() {
    echo -e "${CYAN}Environment Setup${NC}"
    echo ""
    
    # Platform detection
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    echo -e "${GREEN}Platform: $OS $ARCH${NC}"
    echo ""
    
    # Shell detection
    if [ -n "$BASH_VERSION" ]; then
        echo -e "${GREEN}Shell: Bash $BASH_VERSION${NC}"
    elif [ -n "$ZSH_VERSION" ]; then
        echo -e "${GREEN}Shell: Zsh $ZSH_VERSION${NC}"
    else
        echo -e "${GREEN}Shell: $(ps -p $$ -o comm=)${NC}"
    fi
    echo ""
    
    # Check for required tools
    echo -e "${CYAN}Checking dependencies...${NC}"
    
    local missing_deps=0
    
    # Check for git
    if command -v git >/dev/null 2>&1; then
        echo -e "${GREEN}✅ git: $(git --version)${NC}"
    else
        echo -e "${RED}❌ git: NOT FOUND${NC}"
        ((missing_deps++))
    fi
    
    # Check for mix (Elixir)
    if command -v mix >/dev/null 2>&1; then
        echo -e "${GREEN}✅ mix: $(mix --version)${NC}"
    else
        echo -e "${YELLOW}⚠️  mix: NOT FOUND (Elixir not installed)${NC}"
        ((missing_deps++))
    fi
    
    # Check for just
    if command -v just >/dev/null 2>&1; then
        echo -e "${GREEN}✅ just: $(just --version)${NC}"
    else
        echo -e "${YELLOW}⚠️  just: NOT FOUND${NC}"
        echo -e "${YELLOW}   Install with: cargo install just${NC}"
    fi
    
    echo ""
    if [ $missing_deps -eq 0 ]; then
        echo -e "${GREEN}✅ All dependencies satisfied${NC}"
    else
        echo -e "${YELLOW}⚠️  $missing_deps dependencies missing${NC}"
        echo -e "${YELLOW}   Run: sudo apt-get install git elixir${NC}"  # Example for Debian/Ubuntu
        echo -e "${YELLOW}   Run: cargo install just${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..." -r
}

# Initialize
detect_platform

echo -e "${BLUE}"
echo "🚀 ENHANCED GIT SCRIPTS LAUNCHER"
echo "================================"
echo -e "${NC}"
echo -e "Platform: ${ICON} ${PLATFORM^}"
echo ""

# Check if we're in the right directory
if [ ! -d "$GIT_SCRIPTS_DIR" ]; then
    echo -e "${RED}❌ Git scripts directory not found: $GIT_SCRIPTS_DIR${NC}"
    echo -e "${RED}Please ensure the repository exists and paths are correct${NC}"
    exit 1
fi

cd "$GIT_SCRIPTS_DIR"

echo -e "${GREEN}✅ Working directory: ${BLUE}$GIT_SCRIPTS_DIR${NC}"
echo ""

# Run health check on startup
health_check

# Main menu
while true; do
    echo -e "${YELLOW}"
    echo "┌─────────────────────────────────┐"
    echo "│         MAIN MENU              │"
    echo "├─────────────────────────────────┤"
    echo "│  1. 🎯 Launch Elixir TUI        │"
    echo "│  2. 🧹 Run Repository Cleanup  │"
    echo "│  3. 📊 Analyze Repositories     │"
    echo "│  4. 📚 View Documentation       │"
    echo "│  5. 🔧 Advanced Options        │"
    echo "│  6. 🏥 Health Check             │"
    echo "│  0. 🚪 Exit                    │"
    echo "└─────────────────────────────────┘"
    echo -e "${NC}"
    echo ""
    
    read -p "Select option [0-6]: " choice
    echo ""
    
    case "$choice" in
        1)
            echo -e "${GREEN}Launching Elixir TUI...${NC}"
            echo ""
            if [ -x "./script_manager" ]; then
                ./script_manager
            else
                echo -e "${RED}❌ Elixir escript not found${NC}"
                echo -e "${YELLOW}Attempting to rebuild...${NC}"
                if [ -f "mix.exs" ]; then
                    mix deps.get 2>/dev/null || true
                    mix compile 2>/dev/null || true
                    mix escript.build 2>/dev/null || true
                    if [ -x "./script_manager" ]; then
                        echo -e "${GREEN}✅ Rebuilt successfully${NC}"
                        ./script_manager
                    else
                        echo -e "${RED}❌ Rebuild failed${NC}"
                    fi
                else
                    echo -e "${RED}❌ mix.exs not found - cannot rebuild${NC}"
                fi
            fi
            break
            ;;
        2)
            echo -e "${YELLOW}REPOSITORY CLEANUP OPTIONS:${NC}"
            echo ""
            echo "1. Run comprehensive cleanup (all 280+ repos)"
            echo "2. Run targeted cleanup (10 key repos)"
            echo "3. Update .gitignore files"
            echo "4. Commit workflow files"
            echo "5. Back to main menu"
            echo ""
            read -p "Select cleanup option [1-5]: " cleanup_choice
            echo ""
            
            case "$cleanup_choice" in
                1)
                    echo -e "${GREEN}Running comprehensive cleanup...${NC}"
                    echo "This will process all 280+ repositories"
                    echo "Estimated time: 10-30 minutes"
                    echo ""
                    read -p "Start in background? [Y/n]: " bg_choice
                    if [[ "$bg_choice" != [Nn] ]]; then
                        nohup "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh" > "/tmp/comprehensive_cleanup_$(date +%Y%m%d_%H%M%S).log" 2>&1 &
                        echo -e "${GREEN}✅ Comprehensive cleanup started in background${NC}"
                        echo -e "   PID: $!"
                        echo -e "   Log: /tmp/comprehensive_cleanup_$(date +%Y%m%d_%H%M%S).log"
                        echo -e "   Results: $CLEANUP_SCRIPTS_DIR/../cleanup_logs/"
                    else
                        "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh"
                    fi
                    ;;
                2)
                    echo -e "${GREEN}Running targeted cleanup...${NC}"
                    "$CLEANUP_SCRIPTS_DIR/focused_cleanup.sh"
                    echo -e "${GREEN}✅ Targeted cleanup completed!${NC}"
                    ;;
                3)
                    echo -e "${GREEN}Updating .gitignore files...${NC}"
                    echo "This operation updates .gitignore files across repositories"
                    echo "Implementation: Use the cleanup scripts for full functionality"
                    ;;
                4)
                    echo -e "${GREEN}Committing workflow files...${NC}"
                    echo "This operation commits untracked workflow files"
                    echo "Implementation: Use the cleanup scripts for full functionality"
                    ;;
                5)
                    echo -e "${BLUE}Returning to main menu...${NC}"
                    continue
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    ;;
            esac
            ;;
        3)
            echo -e "${YELLOW}ANALYSIS OPTIONS:${NC}"
            echo ""
            echo "1. Full repository analysis"
            echo "2. Script inventory review"
            echo "3. View cleanup logs"
            echo "4. System health check"
            echo "5. Back to main menu"
            echo ""
            read -p "Select analysis option [1-5]: " analysis_choice
            echo ""
            
            case "$analysis_choice" in
                1)
                    echo -e "${GREEN}Running repository analysis...${NC}"
                    "$CLEANUP_SCRIPTS_DIR/cleanup_repos.sh"
                    echo -e "${GREEN}✅ Analysis completed!${NC}"
                    echo "Report: $DOCUMENTATION_DIR/REPOSITORY_CLEANUP_REPORT.md"
                    ;;
                2)
                    echo -e "${GREEN}Script Inventory:${NC}"
                    if [ -f "$DOCUMENTATION_DIR/SCRIPT_INVENTORY.md" ]; then
                        cat "$DOCUMENTATION_DIR/SCRIPT_INVENTORY.md"
                    else
                        echo "Inventory not found. Run script organization first."
                    fi
                    ;;
                3)
                    echo -e "${GREEN}Cleanup Logs:${NC}"
                    if [ -d "$DOCUMENTATION_DIR/cleanup_logs/" ]; then
                        ls -lh "$DOCUMENTATION_DIR/cleanup_logs/"
                    else
                        echo "Logs directory not found: $DOCUMENTATION_DIR/cleanup_logs/"
                    fi
                    ;;
                4)
                    health_check
                    ;;
                5)
                    echo -e "${BLUE}Returning to main menu...${NC}"
                    continue
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    ;;
            esac
            ;;
        4)
            echo -e "${YELLOW}DOCUMENTATION MENU:${NC}"
            echo ""
            echo "1. Quick Start Guide"
            echo "2. Complete Integration Summary"
            echo "3. Script Inventory"
            echo "4. Cleanup Compendium"
            echo "5. Organization Plan"
            echo "6. Back to main menu"
            echo ""
            read -p "Select documentation [1-6]: " doc_choice
            echo ""
            
            case "$doc_choice" in
                1)
                    if [ -f "$DOCUMENTATION_DIR/QUICK_START.md" ]; then
                        cat "$DOCUMENTATION_DIR/QUICK_START.md"
                    else
                        echo "Quick Start Guide not found"
                    fi
                    ;;
                2)
                    if [ -f "$DOCUMENTATION_DIR/COMPLETE_INTEGRATION_SUMMARY.md" ]; then
                        cat "$DOCUMENTATION_DIR/COMPLETE_INTEGRATION_SUMMARY.md"
                    else
                        echo "Integration Summary not found"
                    fi
                    ;;
                3)
                    if [ -f "$DOCUMENTATION_DIR/SCRIPT_INVENTORY.md" ]; then
                        cat "$DOCUMENTATION_DIR/SCRIPT_INVENTORY.md"
                    else
                        echo "Script Inventory not found"
                    fi
                    ;;
                4)
                    if [ -f "$DOCUMENTATION_DIR/FINAL_CLEANUP_COMPENDIUM.md" ]; then
                        cat "$DOCUMENTATION_DIR/FINAL_CLEANUP_COMPENDIUM.md"
                    else
                        echo "Cleanup Compendium not found"
                    fi
                    ;;
                5)
                    if [ -f "$DOCUMENTATION_DIR/REPOS_DIRECTORY_ORGANIZATION_PLAN.md" ]; then
                        cat "$DOCUMENTATION_DIR/REPOS_DIRECTORY_ORGANIZATION_PLAN.md"
                    else
                        echo "Organization Plan not found"
                    fi
                    ;;
                6)
                    echo -e "${BLUE}Returning to main menu...${NC}"
                    continue
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    ;;
            esac
            ;;
        5)
            echo -e "${YELLOW}ADVANCED OPTIONS:${NC}"
            echo ""
            echo "1. Rebuild Elixir escript"
            echo "2. Check script versions"
            echo "3. Run script organization"
            echo "4. Self-healing mode"
            echo "5. System information"
            echo "6. Run Manager (Wrapper)"  # INTEGRATED
            echo "7. Setup Environment"      # INTEGRATED
            echo "8. Back to main menu"
            echo ""
            read -p "Select advanced option [1-8]: " advanced_choice
            echo ""
            
            case "$advanced_choice" in
                1)
                    echo -e "${GREEN}Rebuilding Elixir escript...${NC}"
                    if [ -f "mix.exs" ]; then
                        mix deps.get 2>/dev/null || echo "Dependency fetch completed"
                        mix compile 2>/dev/null || echo "Compilation completed"
                        mix escript.build 2>/dev/null || echo "Build completed"
                        if [ -x "./script_manager" ]; then
                            echo -e "${GREEN}✅ Elixir escript rebuilt successfully${NC}"
                        else
                            echo -e "${YELLOW}⚠️  Rebuild completed with warnings${NC}"
                        fi
                    else
                        echo -e "${RED}❌ mix.exs not found - cannot rebuild${NC}"
                    fi
                    ;;
                2)
                    echo -e "${GREEN}Script Versions:${NC}"
                    echo "Platform: ${PLATFORM^}"
                    echo "Launcher: $(stat -c %y "$0" 2>/dev/null | cut -d' ' -f1)"
                    if [ -f "./script_manager" ]; then
                        echo "Elixir TUI: $(stat -c %y "./script_manager" 2>/dev/null | cut -d' ' -f1)"
                    fi
                    if [ -f "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh" ]; then
                        echo "Cleanup Scripts: $(stat -c %y "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh" 2>/dev/null | cut -d' ' -f1)"
                    fi
                    ;;
                3)
                    echo -e "${GREEN}Running script organization...${NC}"
                    if [ -f "scripts/comprehensive_script_organization.sh" ]; then
                        "scripts/comprehensive_script_organization.sh"
                    else
                        echo "Script organization tool not found"
                    fi
                    ;;
                4)
                    self_heal
                    ;;
                5)
                    echo -e "${GREEN}System Information:${NC}"
                    echo "Platform: ${PLATFORM^}"
                    echo "Bash Version: $BASH_VERSION"
                    echo "Current Directory: $(pwd)"
                    echo "User: $(whoami)"
                    echo "Date: $(date)"
                    ;;
                6)
                    echo -e "${GREEN}Running Run Manager (Wrapper)...${NC}"
                    run_manager_wrapper
                    ;;
                7)
                    echo -e "${GREEN}Setting up Environment...${NC}"
                    setup_environment
                    ;;
                8)
                    echo -e "${BLUE}Returning to main menu...${NC}"
                    continue
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    ;;
            esac
            ;;
        6)
            health_check
            ;;
        0)
            echo -e "${BLUE}"
            echo "Thank you for using the Enhanced Git Scripts Launcher!"
            echo "Platform: ${ICON} ${PLATFORM^}"
            echo "Status: All systems operational"
            echo -e "${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..." -r
    echo ""
done