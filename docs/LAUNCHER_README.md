# Git Scripts Launcher

This directory contains a standardized launcher for the Git Scripts application following the UX Standards from the hyperpolymath ecosystem.

## Files

- `git-scripts-launcher` - Main launcher script (executable)
- `git-scripts.desktop` - Desktop entry file for Dolphin/KDE

## Usage

### From Terminal

```bash
# Start Git Scripts
./git-scripts-launcher --start

# Start and auto-launch (default)
./git-scripts-launcher --auto
# or simply
./git-scripts-launcher

# Stop Git Scripts
./git-scripts-launcher --stop

# Check status
./git-scripts-launcher --status

# Install shortcuts (Linux/macOS/Windows)
./git-scripts-launcher --install
```

### From Dolphin/KDE

1. Double-click the `git-scripts.desktop` file
2. Or right-click and select "Open With" > "Desktop Entry Launcher"
3. The application will start automatically

### Desktop Actions

The desktop file includes additional actions:
- **Stop Git Scripts**: Right-click the desktop file > Actions > Stop Git Scripts
- **Git Scripts Status**: Right-click the desktop file > Actions > Git Scripts Status

## Features

- ✅ Standardized launcher following UX standards
- ✅ Process management with PID tracking
- ✅ Error handling and troubleshooting guidance
- ✅ Multiple launch modes (start, stop, status, auto, install)
- ✅ Desktop integration with actions
- ✅ Cross-platform shortcut installation (Linux/macOS/Windows)
- ✅ Logging to `/tmp/gitscripts-server.log`
- ✅ D-SIP-FV-MA Compliant

## Installation

To install the desktop file system-wide:

```bash
cp git-scripts.desktop ~/.local/share/applications/
```

Then it will appear in your application menu.

## Troubleshooting

If the launcher doesn't work:

1. Check the log file: `tail -50 /tmp/gitscripts-server.log`
2. Verify script_manager exists: `ls -la script_manager`
3. Check process status: `ps aux | grep script_manager`
4. Rebuild if needed: `mix escript.build`

## Compliance

This launcher follows the Comprehensive Launcher Standard:
- D-SIP-FV-MA Compliant
- Process management with PID files
- Error handling and user feedback
- Standard modes (start, stop, status, auto)
- Desktop file integration