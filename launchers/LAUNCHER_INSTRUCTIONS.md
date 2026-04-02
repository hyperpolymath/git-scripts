# 🚀 Git Scripts Launcher - Setup Instructions

## Quick Setup Guide

### 1. Copy Launcher to Desktop

```bash
cp /var/mnt/eclipse/repos/git-scripts/launchers/git-scripts.desktop ~/Desktop/
chmod +x ~/Desktop/git-scripts.desktop
```

### 2. Install Desktop Shortcut

```bash
# Copy desktop file to your desktop
cp /var/mnt/eclipse/repos/git-scripts/launchers/git-scripts.desktop ~/Desktop/

# Make it executable
chmod +x ~/Desktop/git-scripts.desktop

# Update desktop database
update-desktop-database ~/Desktop/
```

### 3. Add to Start Menu (Linux)

```bash
# Copy to local applications
mkdir -p ~/.local/share/applications/
cp /var/mnt/eclipse/repos/git-scripts/launchers/git-scripts.desktop ~/.local/share/applications/

# Update desktop database
update-desktop-database ~/.local/share/applications/
```

### 4. Create Alias for Quick Access

Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
echo "alias gitscripts='/var/mnt/eclipse/repos/git-scripts/launchers/git-scripts-launcher.sh'" >> ~/.bashrc
echo "alias gitscripts='/var/mnt/eclipse/repos/git-scripts/launchers/git-scripts-launcher-enhanced.sh'" >> ~/.bashrc
source ~/.bashrc
```

## Usage

### Launch from Terminal
```bash
gitscripts
```

### Launch from Desktop
- Double-click the desktop shortcut
- Or right-click for additional actions:
  - "Launch TUI Directly"
  - "Run Repository Cleanup"
  - "View Documentation"

### Launch from Start Menu
- Search for "Git Scripts Manager"
- Click to launch

## Launcher Features

### Main Menu Options
1. **🎯 Launch Elixir TUI** - Full interactive interface
2. **🧹 Run Repository Cleanup** - Cleanup operations
3. **📊 Analyze Repositories** - Analysis and reporting
4. **📚 View Documentation** - Complete guides
5. **🔧 Advanced Options** - Rebuild, versions, organization

### Cleanup Options
- Comprehensive cleanup (all 280+ repos)
- Targeted cleanup (10 key repos)
- Update .gitignore files
- Commit workflow files

### Analysis Options
- Full repository analysis
- Script inventory review
- View cleanup logs

### Documentation Options
- Quick Start Guide
- Complete Integration Summary
- Script Inventory
- Cleanup Compendium

### Advanced Options
- Rebuild Elixir escript
- Check script versions
- Run script organization

## Troubleshooting

### Desktop Shortcut Not Working
```bash
# Make sure the desktop file is executable
chmod +x ~/Desktop/git-scripts.desktop

# Update desktop database
update-desktop-database ~/Desktop/
```

### Launcher Not Found
```bash
# Check the launcher exists
ls -la /var/mnt/eclipse/repos/git-scripts/launchers/git-scripts-launcher-enhanced.sh

# Make sure it's executable
chmod +x /var/mnt/eclipse/repos/git-scripts/launchers/git-scripts-launcher-enhanced.sh
```

### Permission Issues
```bash
# Add execute permissions
chmod +x -R /var/mnt/eclipse/repos/git-scripts/launchers/

# Check directory permissions
chmod 755 /var/mnt/eclipse/repos/git-scripts/
```

## Alternative Launch Methods

### Direct TUI Launch
```bash
/var/mnt/eclipse/repos/git-scripts/script_manager
```

### Direct Cleanup Launch
```bash
/var/mnt/eclipse/cleanup_scripts/comprehensive_cleanup.sh
```

### Quick Analysis
```bash
/var/mnt/eclipse/cleanup_scripts/cleanup_repos.sh
```

## Desktop File Customization

Edit the desktop file to customize:
- Name, icon, categories
- Add/remove desktop actions
- Change terminal preferences

```bash
nano /var/mnt/eclipse/repos/git-scripts/launchers/git-scripts.desktop
```

## Launcher Updates

To update the launcher after changes:

```bash
# Pull latest changes
cd /var/mnt/eclipse/repos/git-scripts
git pull

# Rebuild if needed
mix deps.get
mix compile
mix escript.build

# Copy updated launcher
cp launchers/git-scripts-launcher.sh ~/Desktop/
```

## Support

For issues or questions:
- Check documentation: `/var/mnt/eclipse/repos/QUICK_START.md`
- Review script inventory: `/var/mnt/eclipse/repos/SCRIPT_INVENTORY.md`
- Check logs: `/var/mnt/eclipse/repos/cleanup_logs/`

## Quick Reference

```bash
# Launch launcher
gitscripts

# Launch TUI directly
cd /var/mnt/eclipse/repos/git-scripts && ./script_manager

# Run comprehensive cleanup
/var/mnt/eclipse/cleanup_scripts/comprehensive_cleanup.sh

# View quick start
cat /var/mnt/eclipse/repos/QUICK_START.md
```

---

**Status**: ✅ Launcher setup complete
**Location**: `/var/mnt/eclipse/repos/git-scripts/launchers/`
**Ready**: Copy to desktop and start menu for easy access
