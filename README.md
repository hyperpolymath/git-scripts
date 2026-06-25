<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

[![OpenSSF Best Practices](https://img.shields.io/badge/OpenSSF-Best_Practices-green?logo=opensourcesecurity)](https://www.bestpractices.dev/en/projects/new?repo_url=https://github.com/hyperpolymath/git-scripts)
[![License: MPL-2.0](https://img.shields.io/badge/License-MPL_2.0--1.0-blue.svg)](https://github.com/hyperpolymath/palimpsest-license) <embed
src="https://api.thegreenwebfoundation.org/greencheckimage/github.com"
data-link="https://www.thegreenwebfoundation.org/green-web-check/?url=github.com" />

A modern, Elixir-based TUI for managing reusable scripts and functions
across repositories.

# Features

- **Wiki Audit**: Check wiki content for issues

- **Project Tabs Audit**: Verify GitHub project tab configurations

- **Branch Protection**: Apply branch protection rules

- **MD to ADOC Converter**: Convert Markdown to AsciiDoc format

- **Standardize READMEs**: Ensure consistent README formatting

- **Update Repos**: Mass update repositories

- **Audit Scripts**: Security and quality checks

- **Verify**: Repository configuration verification

- **GH CLI**: GitHub CLI utilities

- **Repository Cleanup**: Comprehensive cleanup and maintenance

# Architecture

- **Language**: Elixir (OTP-based, fault-tolerant)

- **Pattern**: Modular OTP application with supervisor

- **Interface**: Interactive TUI with menu system

- **Execution**: Standalone escript (no runtime dependencies)

# Usage

## Run the TUI

```bash
cd /var/mnt/eclipse/repos/git-scripts
./launchers/git-scripts-launcher-enhanced.sh
```

## Build from Source

```bash
mix deps.get
mix compile
mix escript.build
```

# Implementation Details

Each function is implemented as an Elixir module:

- `ScriptManager.WikiAudit` — Wiki auditing

- `ScriptManager.ProjectTabsAudit` — Project tab verification

- `ScriptManager.BranchProtection` — Branch protection rules

- `ScriptManager.MDConverter` — Format conversion

- `ScriptManager.ReadmeStandardizer` — README standardization

- `ScriptManager.RepoUpdater` — Repository updates

- `ScriptManager.ScriptAuditor` — Script auditing

- `ScriptManager.Verifier` — Configuration verification

- `ScriptManager.GHCLI` — GitHub CLI utilities

- `ScriptManager.RepoCleanup` — Repository cleanup and maintenance

# Future Development

- Add real file system operations

- Implement GitHub API integration

- Add configuration management

- Enhance error handling and logging

- Add progress reporting

# Shortcuts

- **Desktop**: `launchers/git-scripts.desktop`

- **Start Menu**: `~/.local/share/applications/git-scripts.desktop`

# Benefits over Bash Version

1.  **Type Safety**: Elixir’s strong typing prevents many runtime errors

2.  **Concurrency**: Built-in support for parallel operations

3.  **Fault Tolerance**: OTP supervision trees handle errors gracefully

4.  **Maintainability**: Clear module structure and documentation

5.  **Extensibility**: Easy to add new functions as modules

6.  **Performance**: Compiled BEAM bytecode runs efficiently

Wondering how this works? See [EXPLAINME.adoc](EXPLAINME.adoc).

# License

SPDX-License-Identifier: CC-BY-SA-4.0 See [LICENSE](LICENSE).
