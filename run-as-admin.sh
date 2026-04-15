#!/usr/bin/env bash
set -euo pipefail

# Run the script_manager directly as admin
cd /var/mnt/eclipse/repos/git-scripts
export SCRIPT_MANAGER_DISABLE_WEB=1

# Force interactive mode by redirecting input from /dev/tty
/var/mnt/eclipse/repos/git-scripts/script_manager < /dev/tty

# Keep the terminal open
read -p "Press Enter to close..." -r
