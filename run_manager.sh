#!/usr/bin/env bash
# Wrapper script to run Elixir script manager

cd /var/mnt/eclipse/repos/git-scripts
./launchers/git-scripts-launcher-enhanced.sh

echo ""
echo "Script manager exited. Press Enter to close..."
read -r
