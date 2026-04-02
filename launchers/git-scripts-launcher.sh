#!/bin/bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Git Scripts Launcher - Easy access to the Elixir TUI with cleanup integration

set -euo pipefail

# Configuration
GIT_SCRIPTS_DIR="/var/mnt/eclipse/repos/git-scripts"
CLEANUP_SCRIPTS_DIR="/var/mnt/eclipse/cleanup_scripts"
DOCUMENTATION_DIR="/var/mnt/eclipse/repos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "🚀 GIT SCRIPTS LAUNCHER"
echo "======================"
echo -e "${NC}"
echo ""

# Check if we're in the right directory
cd "$GIT_SCRIPTS_DIR"

echo -e "${GREEN}✅ Working directory set: ${BLUE}$GIT_SCRIPTS_DIR${NC}"
echo ""

# Main menu
while true; do
    echo -e "${YELLOW}MAIN MENU:${NC}"
    echo ""
    echo "1. 🎯 Launch Elixir TUI (Full Interface)"
    echo "2. 🧹 Run Repository Cleanup"
    echo "3. 📊 Analyze Repositories"
    echo "4. 📚 View Documentation"
    echo "5. 🔧 Advanced Options"
    echo "0. 🚪 Exit"
    echo ""
    
    read -p "Select option [0-5]: " choice
    echo ""
    
    case "$choice" in
        1)
            echo -e "${GREEN}Launching Elixir TUI...${NC}"
            echo ""
            ./script_manager
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
                    nohup "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh" > /tmp/comprehensive_cleanup_$(date +%Y%m%d).log 2>&1 &
                    echo -e "${GREEN}✅ Comprehensive cleanup started in background${NC}"
                    echo -e "   Log: /tmp/comprehensive_cleanup_$(date +%Y%m%d).log"
                    echo -e "   Results: $CLEANUP_SCRIPTS_DIR/../cleanup_logs/"
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
            echo "4. Back to main menu"
            echo ""
            read -p "Select analysis option [1-4]: " analysis_choice
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
                    cat "$DOCUMENTATION_DIR/SCRIPT_INVENTORY.md"
                    ;;
                3)
                    echo -e "${GREEN}Cleanup Logs:${NC}"
                    ls -lh "$DOCUMENTATION_DIR/cleanup_logs/" 2>/dev/null || echo "No logs found"
                    ;;
                4)
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
            echo "5. Back to main menu"
            echo ""
            read -p "Select documentation [1-5]: " doc_choice
            echo ""
            
            case "$doc_choice" in
                1)
                    cat "$DOCUMENTATION_DIR/QUICK_START.md"
                    ;;
                2)
                    cat "$DOCUMENTATION_DIR/COMPLETE_INTEGRATION_SUMMARY.md"
                    ;;
                3)
                    cat "$DOCUMENTATION_DIR/SCRIPT_INVENTORY.md"
                    ;;
                4)
                    cat "$DOCUMENTATION_DIR/FINAL_CLEANUP_COMPENDIUM.md"
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
        5)
            echo -e "${YELLOW}ADVANCED OPTIONS:${NC}"
            echo ""
            echo "1. Rebuild Elixir escript"
            echo "2. Check script versions"
            echo "3. Run script organization"
            echo "4. Back to main menu"
            echo ""
            read -p "Select advanced option [1-4]: " advanced_choice
            echo ""
            
            case "$advanced_choice" in
                1)
                    echo -e "${GREEN}Rebuilding Elixir escript...${NC}"
                    mix deps.get
                    mix compile
                    mix escript.build
                    echo -e "${GREEN}✅ Elixir escript rebuilt${NC}"
                    ;;
                2)
                    echo -e "${GREEN}Script Versions:${NC}"
                    echo "Elixir TUI: $(stat -c %y "$GIT_SCRIPTS_DIR/script_manager" | cut -d' ' -f1)"
                    echo "Cleanup Scripts: $(stat -c %y "$CLEANUP_SCRIPTS_DIR/comprehensive_cleanup.sh" | cut -d' ' -f1)"
                    ;;
                3)
                    echo -e "${GREEN}Running script organization...${NC}"
                    "$GIT_SCRIPTS_DIR/scripts/comprehensive_script_organization.sh"
                    ;;
                4)
                    echo -e "${BLUE}Returning to main menu...${NC}"
                    continue
                    ;;
                *)
                    echo -e "${RED}Invalid choice${NC}"
                    ;;
            esac
            ;;
        0)
            echo -e "${BLUE}Thank you for using Git Scripts Launcher!${NC}"
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