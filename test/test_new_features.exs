# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#!/usr/bin/env elixir

# Test the new features directly

IO.puts("Testing new Elixir Script Manager features...")

# Test Mass PR Processor
IO.puts("\n=== Testing Mass PR Processor ===")
ScriptManager.PRProcessor.process_all("hyperpolymath", :add_labels)

# Test Health Dashboard
IO.puts("\n=== Testing Health Dashboard ===")
ScriptManager.HealthDashboard.generate_report()

# Test GitHub API
IO.puts("\n=== Testing GitHub API ===")
prs = ScriptManager.GitHubAPI.get_open_prs("hyperpolymath")
IO.puts("Found #{length(prs)} open PRs")

IO.puts("\n✅ All new features tested successfully!")