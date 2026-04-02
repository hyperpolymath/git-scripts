#!/usr/bin/env elixir

# Test the new features without full compilation

IO.puts("Testing new Elixir Script Manager features...")

# Test GitHub API module exists
try do
  Code.require_file("lib/script_manager/github_api.ex", __DIR__)
  IO.puts("✅ GitHub API module loaded")
rescue
  e ->
  IO.puts("❌ GitHub API module error: #{inspect(e)}")
end

# Test PR Processor module exists
try do
  Code.require_file("lib/script_manager/pr_processor.ex", __DIR__)
  IO.puts("✅ PR Processor module loaded")
rescue
  e ->
  IO.puts("❌ PR Processor module error: #{inspect(e)}")
end

# Test Health Dashboard module exists
try do
  Code.require_file("lib/script_manager/health_dashboard.ex", __DIR__)
  IO.puts("✅ Health Dashboard module loaded")
rescue
  e ->
  IO.puts("❌ Health Dashboard module error: #{inspect(e)}")
end

IO.puts("\nFeature test complete!")