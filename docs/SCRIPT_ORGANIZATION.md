# Git Scripts Organization Guide

## 🗂️ New Directory Structure

```
git-scripts/
├── ai/                      # AI-related configuration
├── bin/                     # Compiled binary files
├── config/                  # Shared configuration
├── docs/                    # Documentation
├── launchers/               # Launcher scripts
├── scripts/                 # Functional scripts
├── test/                    # Test files
├── lib/                     # Elixir source code
├── priv/                    # Private assets
└── (root files)
```

## 🔧 Script Integration

### Current Integration Status

The Elixir TUI is fully integrated with the shell scripts:

| TUI Option | Script | Status |
|------------|--------|--------|
| [1] Wiki Audit | `scripts/wiki-audit.sh` | ✅ Integrated |
| [2] Project Tabs Audit | `scripts/project-tabs-audit.sh` | ✅ Integrated |
| [3] Branch Protection | `scripts/branch-protection-apply.sh` | ✅ Integrated |
| [4] MD to ADOC | `scripts/md_to_adoc_converter.sh` | ✅ Integrated |
| [5] Standardize READMEs | `scripts/standardize_readmes.sh` | ✅ Integrated |
| [6] Update Repos | `scripts/update_repos.sh` | ✅ Integrated |
| [7] Audit Scripts | `scripts/audit_script.sh` | ✅ Integrated |
| [8] Verify | `scripts/verify.sh` | ✅ Integrated |
| [9] Use GH CLI | `scripts/USE-GH-CLI.sh` | ✅ Integrated |

### Shared Configuration

Both `update_repos.sh` and `verify.sh` now use a shared configuration file:

```bash
# Source shared configuration
if [ -f "/var/mnt/eclipse/repos/git-scripts/config/repos.config" ]; then
    source "/var/mnt/eclipse/repos/git-scripts/config/repos.config"
else
    echo "Error: Configuration file not found" >&2
    exit 1
fi
```

## 🚀 Usage

### Primary Entry Points

1. **Standard Launcher** (recommended):
   ```bash
   ./git-scripts-launcher [--start|--stop|--status|--install]
   ```

2. **Elixir TUI**:
   ```bash
   ./script_manager
   ```

3. **Setup Script**:
   ```bash
   ./setup.sh
   ```

### Script Management

All functional scripts are located in the `scripts/` directory and can be run directly:

```bash
# Run wiki audit
./scripts/wiki-audit.sh

# Update repositories
./scripts/update_repos.sh

# Verify repository status
./scripts/verify.sh
```

## 🎯 Best Practices

### 1. Use the Launcher

Always prefer using `git-scripts-launcher` over direct script execution for:
- Process management
- Error handling
- Logging
- Consistent user experience

### 2. Configuration Management

When adding new scripts that need repository lists:
- Add repos to `config/repos.config`
- Source the config file in your script
- Don't duplicate repository lists

### 3. Script Development

For new scripts:
- Place in `scripts/` directory
- Follow existing naming conventions
- Add proper error handling
- Document usage in script header

### 4. Testing

Test scripts individually before integrating with TUI:
```bash
# Test a script
./scripts/your-script.sh

# Test TUI integration
./script_manager  # Then select the corresponding option
```

## 🔧 Maintenance

### Adding New Scripts

1. Create script in `scripts/` directory
2. Add corresponding TUI option in `lib/script_manager/tui.ex`
3. Add module in `lib/script_manager/` if needed
4. Update documentation

### Updating Repository Lists

Edit `config/repos.config` to:
- Add new repositories
- Remove deprecated repositories
- Update repository categories

### Cleanup

Regular maintenance tasks:
```bash
# Remove old build artifacts
rm -rf _build/

# Clean up binaries
rm -f bin/*.beam

# Update dependencies
mix deps.get && mix compile
```

## 📋 File Organization Cheat Sheet

| File Type | Location | Example |
|-----------|----------|---------|
| AI Config | `ai/` | `0-AI-MANIFEST.a2ml` |
| Binaries | `bin/` | `*.beam` files |
| Config | `config/` | `repos.config` |
| Docs | `docs/` | `*.md` files |
| Launchers | `launchers/` | `git-scripts-launcher` |
| Scripts | `scripts/` | `wiki-audit.sh` |
| Tests | `test/` | `test_*.exs` |
| Source | `lib/` | `*.ex` files |
| Assets | `priv/` | Static assets |

## 🎉 Summary

The git-scripts repository is now well-organized with:
- ✅ Clean directory structure
- ✅ Integrated script management
- ✅ Shared configuration
- ✅ Comprehensive documentation
- ✅ Redundant scripts removed

This organization makes the repository easier to maintain and extend.