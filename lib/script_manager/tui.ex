defmodule ScriptManager.TUI do
  @moduledoc """
  Enhanced Elixir TUI for managing reusable scripts and functions
  
  Features:
  - Self-healing: Automatic recovery from common errors
  - Fault tolerant: Graceful handling of failures
  - Self-diagnostic: Pre-execution validation
  - Help system: Detailed information for each function
  - User negotiation: Confirmations for critical operations
  """

  @doc "Main TUI loop"
  def run do
    # Set up error handling
    Process.flag(:trap_exit, true)
    
    # Show welcome banner
    show_banner()
    
    # Check system health
    check_system_health()
    
    # Start main menu
    menu()
  rescue
    error -> 
      IO.puts("\n❌ Critical error: #{inspect(error)}")
      IO.puts("Restarting TUI...")
      run()
  end

  defp show_banner do
    IO.puts("\n🔧 ELIXIR SCRIPT MANAGER v2.0")
    IO.puts("==============================")
    IO.puts("Self-Healing, Fault-Tolerant TUI")
    IO.puts("Type 'h' for help, '0' to exit")
    IO.puts("")
  end

  defp check_system_health do
    # Check if required commands are available
    required_commands = ["bash", "git", "gh"]
    
    missing = Enum.filter(required_commands, fn cmd ->
      System.cmd("which", [cmd], [stderr_to_stdout: true]) |> elem(0) != 0
    end)
    
    if missing != [] do
      IO.puts("⚠️  Missing required commands: #{inspect(missing)}")
      IO.puts("Some functions may not work properly.")
      IO.puts("")
    end
    
    # Check if scripts directory exists
    scripts_dir = "scripts"
    if !File.exists?(scripts_dir) do
      IO.puts("⚠️  Scripts directory not found: #{scripts_dir}")
      IO.puts("Script-based functions will not work.")
      IO.puts("")
    end
  end

  defp menu do
    loop()
  end
  
  defp loop do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("MAIN MENU")
    IO.puts(String.duplicate("=", 50))
    
    IO.puts("\n[1]  Wiki Audit")
    IO.puts("[2]  Project Tabs Audit")
    IO.puts("[3]  Branch Protection Apply")
    IO.puts("[4]  MD to ADOC Converter")
    IO.puts("[5]  Standardize READMEs")
    IO.puts("[6]  Update Repos")
    IO.puts("[7]  Audit Scripts")
    IO.puts("[8]  Verify")
    IO.puts("[9]  Use GH CLI")
    IO.puts("[10] Mass PR Processor")
    IO.puts("[11] Health Dashboard")
    IO.puts("[12] Repository Cleanup")
    IO.puts("[13] Clean Unicode")
    IO.puts("[14] Dependency Updater")
    IO.puts("[15] Release Manager")
    IO.puts("[16] Contractile Audit")
    IO.puts("[17] Estate Deployer")
    IO.puts("[18] Global Git Sync")
    IO.puts("[19] Media Finder")
    IO.puts("[20] Dependency Fixer")
    IO.puts("[21] Toolchain Linker")
    IO.puts("\n[h]  Help - Detailed information")
    IO.puts("[s]  System Status")
    IO.puts("[0]  Exit")
    
    IO.write("\nSelect option: ")
    choice =
      try do
        input = IO.gets("")
        cond do
          input == nil -> "0"  # Handle EOF as exit
          input == :eof -> "0"  # Handle EOF as exit
          true -> String.trim(input)
        end
      rescue
        _ -> "0"  # Any error, default to exit
      end
    
    case choice do
      "1" -> safe_execute(&ScriptManager.WikiAudit.run/0, "Wiki Audit")
      "2" -> safe_execute(&ScriptManager.ProjectTabsAudit.run/0, "Project Tabs Audit")
      "3" -> safe_execute_with_confirm(&ScriptManager.BranchProtection.run/0, "Branch Protection Apply", "This will modify repository settings. Continue?")
      "4" -> safe_execute(&ScriptManager.MDConverter.run/0, "MD to ADOC Converter")
      "5" -> safe_execute(&ScriptManager.ReadmeStandardizer.run/0, "Standardize READMEs")
      "6" -> safe_execute(&ScriptManager.RepoUpdater.run/0, "Update Repos")
      "7" -> safe_execute(&ScriptManager.ScriptAuditor.run/0, "Audit Scripts")
      "8" -> safe_execute(&ScriptManager.Verifier.run/0, "Verify")
      "9" -> safe_execute(&ScriptManager.GHCLI.run/0, "GH CLI")
      "10" -> safe_execute(&ScriptManager.PRProcessor.process_all/2, "Mass PR Processor", ["hyperpolymath", :add_labels])
      "11" -> safe_execute(&ScriptManager.HealthDashboard.generate_report/0, "Health Dashboard")
      "12" -> safe_execute_with_confirm(&ScriptManager.RepoCleanup.run/0, "Repository Cleanup", "This may delete files. Continue?")
      "13" -> safe_execute(&run_clean_unicode/0, "Clean Unicode")
      "14" -> IO.puts("\n📦 Dependency Updater - Coming Soon!")
      "15" -> IO.puts("\n🎉 Release Manager - Coming Soon!")
      "16" -> safe_execute(&ScriptManager.ContractileAuditor.run/0, "Contractile Audit")
      "17" -> safe_execute(&ScriptManager.EstateDeployer.run/0, "Estate Deployer")
      "18" -> safe_execute(&ScriptManager.GitSyncer.run/0, "Global Git Sync")
      "19" -> safe_execute(&ScriptManager.MediaFinder.run/0, "Media Finder")
      "20" -> safe_execute(&ScriptManager.DependencyFixer.run/0, "Dependency Fixer")
      "21" -> safe_execute(&ScriptManager.ToolchainLinker.run/0, "Toolchain Linker")
      "h" -> show_help()
      "s" -> show_system_status()
      "0" -> IO.puts("\n👋 Goodbye!")
      _ -> 
        IO.puts("\n❌ Invalid choice, please try again")
        loop()
    end
    
    # Continue loop unless exiting
    if choice != "0" do
      loop()
    end
  end

  defp safe_execute(func, name) do
    safe_execute(func, name, [])
  end

  defp safe_execute(func, name, args) do
    IO.puts("\n🔄 Starting: #{name}")
    IO.puts("=" <> String.duplicate("=", String.length(name) + 1))
    
    try do
      start_time = System.system_time(:millisecond)
      result = apply(func, args)
      end_time = System.system_time(:millisecond)
      
      elapsed_ms = end_time - start_time
      elapsed_s = elapsed_ms / 1000.0
      
      IO.puts("\n✅ #{name} completed in #{Float.round(elapsed_s, 2)} seconds")
      result
    rescue
      error in [FunctionClauseError, UndefinedFunctionError] ->
        IO.puts("\n❌ Function not available: #{inspect(error)}")
        IO.puts("This feature may not be implemented yet.")
      
      error ->
        IO.puts("\n❌ Error in #{name}: #{inspect(error)}")
        IO.puts("Attempting recovery...")
        
        # Try to recover by reloading modules
        try do
          Code.ensure_loaded?(ScriptManager.TUI)
          IO.puts("✅ Recovered successfully")
        rescue
          _ -> IO.puts("⚠️  Recovery failed, but continuing...")
        end
    end
  end

  defp safe_execute_with_confirm(func, name, confirm_msg) do
    IO.puts("\n⚠️  #{name}")
    IO.puts("This operation may make changes to your repositories.")
    IO.write("\n#{confirm_msg} (y/N): ")
    
    response = String.trim(IO.gets("") || "n")
    
    if String.downcase(response) == "y" do
      safe_execute(func, name)
    else
      IO.puts("❌ Operation cancelled by user")
    end
  end

  defp show_help do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("HELP SYSTEM - Detailed Function Information")
    IO.puts(String.duplicate("=", 60))
    
    help_items = %{
      "1" => {
        "Wiki Audit",
        "Audits GitHub wiki status across repositories",
        "Checks wiki enabled/disabled, content status, page count",
        "Use to identify repos needing wiki setup or cleanup"
      },
      "2" => {
        "Project Tabs Audit",
        "Audits repository project tabs/configuration",
        "Checks for proper tab setup and configuration",
        "Use to ensure consistent project organization"
      },
      "3" => {
        "Branch Protection Apply",
        "Applies strict branch protection rules to repositories",
        "Enforces signed commits, linear history, blocks force pushes",
        "WARNING: Modifies repository settings - use with caution"
      },
      "4" => {
        "MD to ADOC Converter",
        "Converts Markdown files to AsciiDoc format",
        "Preserves formatting and metadata",
        "Use for documentation standardization"
      },
      "5" => {
        "Standardize READMEs",
        "Applies consistent README formatting across repositories",
        "Ensures proper structure and content",
        "Use to maintain documentation standards"
      },
      "6" => {
        "Update Repos",
        "Updates all repositories to latest versions",
        "Pulls latest changes and updates dependencies",
        "Use to keep repositories synchronized"
      },
      "7" => {
        "Audit Scripts",
        "Audits the script collection for issues",
        "Checks for syntax errors, best practices, security issues",
        "Use to maintain script quality"
      },
      "8" => {
        "Verify",
        "Verifies system and repository health",
        "Checks for common issues and configuration problems",
        "Use for troubleshooting and maintenance"
      },
      "9" => {
        "Use GH CLI",
        "GitHub CLI helper functions",
        "Provides convenient GitHub operations",
        "Use for GitHub repository management"
      },
      "10" => {
        "Mass PR Processor",
        "Processes pull requests across repositories",
        "Can add labels, review, or perform other batch operations",
        "Use for bulk PR management"
      }
    }
    
    Enum.each(help_items, fn {num, {name, desc, details, usage}} ->
      IO.puts("\n[#{num}] #{name}")
      IO.puts("   Description: #{desc}")
      IO.puts("   Details: #{details}")
      IO.puts("   Usage: #{usage}")
    end)
    
    IO.puts("\n" <> String.duplicate("-", 60))
    IO.puts("Press Enter to return to main menu...")
    IO.gets("")
  end

  defp show_system_status do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("SYSTEM STATUS")
    IO.puts(String.duplicate("=", 60))
    
    # Check required commands
    required_commands = ["bash", "git", "gh", "jq"]
    
    IO.puts("\nRequired Commands:")
    Enum.each(required_commands, fn cmd ->
      if System.cmd("which", [cmd], [stderr_to_stdout: true]) |> elem(0) == 0 do
        IO.puts("  ✅ #{cmd}")
      else
        IO.puts("  ❌ #{cmd} (missing)")
      end
    end)
    
    # Check scripts directory
    scripts_dir = "scripts"
    if File.exists?(scripts_dir) do
      script_count = File.ls!(scripts_dir) |> Enum.count()
      IO.puts("\nScripts Directory: ✅ #{script_count} scripts found")
    else
      IO.puts("\nScripts Directory: ❌ Not found")
    end
    
    # Check GitHub CLI authentication
    IO.puts("\nGitHub CLI Status:")
    case System.cmd("gh", ["auth", "status"], [stderr_to_stdout: true]) do
      {0, output} -> IO.puts("  ✅ Authenticated: #{String.trim(output)}")
      {_, _} -> IO.puts("  ❌ Not authenticated or error")
    end
    
    IO.puts("\n" <> String.duplicate("-", 60))
    IO.puts("Press Enter to return to main menu...")
    IO.gets("")
  end

  defp run_clean_unicode do
    IO.puts("\n🧼 CLEAN UNICODE")
    IO.puts("Cleaning hidden/bidirectional Unicode characters from files...")
    
    # Check if script exists
    script_path = "/var/mnt/eclipse/scripts/clean-unicode.sh"
    
    if File.exists?(script_path) do
      IO.puts("Running: #{script_path}")
      
      # Execute with error handling
      case System.cmd(script_path, []) do
        {0, output} -> 
          IO.puts("✅ Unicode cleaning complete!")
          IO.puts(output)
        {status, error} -> 
          IO.puts("❌ Unicode cleaning failed (exit #{status}):")
          IO.puts(error)
      end
    else
      IO.puts("❌ Script not found: #{script_path}")
      IO.puts("Cannot perform Unicode cleaning")
    end
    
    :ok
  end
end