<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->
# TOPOLOGY.md — git-scripts

## Purpose

Elixir-based TUI for managing reusable scripts and repository maintenance tasks across the hyperpolymath estate. Provides wiki audits, branch protection enforcement, README standardisation, mass repo updates, and GitHub CLI utilities via a script manager interface.

## Module Map

```
git-scripts/
├── lib/
│   ├── script_manager/
│   │   ├── script_manager.ex          # Main TUI entry point
│   │   ├── GitHubAPI.beam             # GitHub API client
│   │   ├── HealthDashboard.beam       # Repo health dashboard
│   │   ├── PRProcessor.beam           # PR automation
│   │   └── SimpleJSON.beam            # Lightweight JSON handling
│   └── script_manager.ex              # Application root
├── launchers/                         # Shell launcher scripts
├── config/                            # App configuration
└── mix.exs                            # Mix project config
```

## Data Flow

```
[User TUI input] ──► [ScriptManager] ──► [GitHubAPI] ──► [GitHub REST API]
                                    └──► [PRProcessor]
                                    └──► [HealthDashboard] ──► [Console output]
```
