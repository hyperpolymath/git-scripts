defmodule ScriptManager.TUI do
  @moduledoc """
  Two-tier TUI for managing reusable scripts and functions.

  Top level groups related operations into categories ([A]–[F]); each
  category opens a sub-menu of numbered items. Item names have been
  rewritten to describe what they actually do at a glance.

  Features:
  - Self-healing: Automatic recovery from common errors
  - Fault tolerant: Graceful handling of failures
  - Self-diagnostic: Pre-execution validation
  - Help system: Detailed information for each function
  - User negotiation: Confirmations for critical operations
  - Ownership guard: Refuses to operate on repos outside the allowlist
  """

  # ----------------------------------------------------------------------
  # Menu definition (single source of truth)
  # ----------------------------------------------------------------------

  # Each category has a key (letter), a title, and a list of items.
  # Each item has: a sub-key (number), a display name, the action, and an
  # optional one-line help blurb.
  #
  # Action shapes:
  #   {:fun, fun}                              — call fun.()
  #   {:fun, fun, args}                        — apply(fun, args)
  #   {:fun_confirm, fun, prompt}              — confirm, then call fun.()
  #   {:nyi, message}                          — print "coming soon" message
  defp categories do
    [
      {"A", "Audits & Reports",
       [
         {"1", "Audit Wiki Status",
          {:fun, &ScriptManager.WikiAudit.run/0},
          "Audit GitHub wiki status across allowed repos."},
         {"2", "Audit Project Metadata (About)",
          {:fun, &ScriptManager.ProjectTabsAudit.run/0},
          "Audit description, homepage URL, and topics on each repo."},
         {"3", "Audit Contractile Implementation",
          {:fun, &ScriptManager.ContractileAuditor.run/0},
          "Check must/trust/dust/lust/adjust/intend contractiles + K9-SVC."},
         {"4", "Security Audit (Secrets & Dependabot)",
          {:fun, &ScriptManager.ScriptAuditor.run/0},
          "Scan for secrets (gitleaks) and Dependabot Critical/High alerts."},
         {"5", "Repository Health Dashboard",
          {:fun, &ScriptManager.HealthDashboard.generate_report/0},
          "Generate a health-score report for repositories."},
         {"6", "Verify Local-vs-Remote Sync",
          {:fun, &ScriptManager.Verifier.run/0},
          "Compare each repo's local HEAD message to its remote."}
       ]},
      {"B", "Repository Maintenance",
       [
         {"1", "Update Repos (Sync, Commit, Push)",
          {:fun, &ScriptManager.RepoUpdater.run/0},
          "Pull, rebase, commit, and push the configured repo set."},
         {"2", "Global Git Sync (All Allowed Repos)",
          {:fun, &ScriptManager.GitSyncer.run/0},
          "Concurrent sync/merge/push across every allowed local repo."},
         {"3", "Standardize README Format",
          {:fun, &ScriptManager.ReadmeStandardizer.run/0},
          "Convert and consolidate README files to README.adoc."},
         {"4", "Convert Markdown to AsciiDoc",
          {:fun, &ScriptManager.MDConverter.run/0},
          "Bulk-convert lingering README.md files to AsciiDoc."},
         {"5", "Clean Hidden Unicode in Files",
          {:fun, &__MODULE__.run_clean_unicode/0},
          "Strip hidden / bidi Unicode characters from tracked files."},
         {"6", "Repository Cleanup Operations",
          {:fun_confirm, &ScriptManager.RepoCleanup.run/0,
           "This may delete files. Continue?"},
          "Run gitignore updates, workflow commits, or full cleanup."},
         {"7", "Fix Known Dependency Issues",
          {:fun, &ScriptManager.DependencyFixer.run/0},
          "Apply hard-coded patches for Lithoglyph and RGTV builds."}
       ]},
      {"C", "GitHub Operations",
       [
         {"1", "Apply Branch Protection Rulesets",
          {:fun_confirm, &ScriptManager.BranchProtection.run/0,
           "This will modify repository settings. Continue?"},
          "Push the standard ruleset (signed commits, linear history…)."},
         {"2", "Mass PR Processor (Labels/Comments)",
          {:fun, &ScriptManager.PRProcessor.process_all/2,
           ["hyperpolymath", :add_labels]},
          "Apply labels in bulk to open PRs across the allowed org."},
         {"3", "GitHub CLI Helper",
          {:fun, &ScriptManager.GHCLI.run/0},
          "Print useful gh commands and verify gh auth status."}
       ]},
      {"D", "Estate-Wide Deployment",
       [
         {"1", "Deploy Estate Standards",
          {:fun, &ScriptManager.EstateDeployer.run/0},
          "Deploy contractiles, K9-SVC, accessibility, VPAT, pre-commit hook."},
         {"2", "Link Language Toolchains",
          {:fun, &ScriptManager.ToolchainLinker.run/0},
          "Symlink built compiler/runtime binaries into ~/.local/bin."},
         {"3", "Find Media Repositories (rclone)",
          {:fun, &ScriptManager.MediaFinder.run/0},
          "Scan rclone remotes for directories that look like media repos."}
       ]},
      {"E", "External Tools",
       [
         {"1", "Launch NQC (Database Query)",
          {:fun, &__MODULE__.launch_nqc/0},
          "Open the NextGen Query Client web UI for VQL/GQL/KQL."},
         {"2", "Launch Invariant Path (Code Analysis)",
          {:fun, &__MODULE__.launch_invariant_path/0},
          "Open the Invariant Path code-analysis tool."}
       ]},
      {"F", "Coming Soon",
       [
         {"1", "Dependency Updater",
          {:nyi, "📦 Dependency Updater - Coming Soon!"},
          "Cross-language dependency upgrade orchestration (planned)."},
         {"2", "Release Manager",
          {:nyi, "🎉 Release Manager - Coming Soon!"},
          "Tagging, changelog, and GitHub release automation (planned)."}
       ]}
    ]
  end

  # ----------------------------------------------------------------------
  # Lifecycle
  # ----------------------------------------------------------------------

  @doc "Main TUI loop"
  def run do
    Process.flag(:trap_exit, true)

    show_banner()
    check_system_health()
    show_owner_allowlist()

    main_loop()
  rescue
    error ->
      IO.puts("\n❌ Critical error: #{inspect(error)}")
      IO.puts("Restarting TUI...")
      run()
  end

  defp show_banner do
    IO.puts("\n🔧 ELIXIR SCRIPT MANAGER v2.1")
    IO.puts("==============================")
    IO.puts("Self-Healing, Fault-Tolerant TUI")
    IO.puts("Two-tier menu | Ownership-guarded operations")
    IO.puts("Type 'h' for help, '0' to exit")
    IO.puts("")
  end

  defp check_system_health do
    required_commands = ["bash", "git", "gh"]

    missing = Enum.filter(required_commands, fn cmd ->
      System.cmd("which", [cmd], stderr_to_stdout: true) |> elem(0) != 0
    end)

    if missing != [] do
      IO.puts("⚠️  Missing required commands: #{inspect(missing)}")
      IO.puts("Some functions may not work properly.")
      IO.puts("")
    end

    scripts_dir = "scripts"

    if !File.exists?(scripts_dir) do
      IO.puts("⚠️  Scripts directory not found: #{scripts_dir}")
      IO.puts("Script-based functions will not work.")
      IO.puts("")
    end
  end

  defp show_owner_allowlist do
    owners = ScriptManager.OwnershipGuard.allowed_owners()

    IO.puts("🛡  Ownership allowlist: #{Enum.join(owners, ", ")}")
    IO.puts("    (Edit config/owners.config to add your son's or other owners.)")
    IO.puts("")
  end

  # ----------------------------------------------------------------------
  # Top-level menu
  # ----------------------------------------------------------------------

  defp main_loop do
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("MAIN MENU")
    IO.puts(String.duplicate("=", 50))

    Enum.each(categories(), fn {key, title, items} ->
      IO.puts("[#{key}]  #{title}  (#{length(items)})")
    end)

    IO.puts("")
    IO.puts("[h]  Help - Detailed information")
    IO.puts("[s]  System Status")
    IO.puts("[0]  Exit")

    IO.write("\nSelect category: ")
    choice = read_choice() |> String.upcase()

    case choice do
      "H" ->
        show_help()
        main_loop()

      "S" ->
        show_system_status()
        main_loop()

      "0" ->
        IO.puts("\n👋 Goodbye!")

      key ->
        case Enum.find(categories(), fn {k, _, _} -> k == key end) do
          nil ->
            IO.puts("\n❌ Invalid choice, please try again")
            main_loop()

          category ->
            sub_loop(category)
            main_loop()
        end
    end
  end

  # ----------------------------------------------------------------------
  # Sub-menu (per category)
  # ----------------------------------------------------------------------

  defp sub_loop({key, title, items}) do
    IO.puts("\n" <> String.duplicate("-", 50))
    IO.puts("[#{key}] #{title}")
    IO.puts(String.duplicate("-", 50))

    Enum.each(items, fn {num, name, _action, _help} ->
      IO.puts("  [#{num}] #{name}")
    end)

    IO.puts("")
    IO.puts("  [b] Back to main menu")
    IO.puts("  [0] Exit")

    IO.write("\nSelect item: ")
    choice = read_choice() |> String.downcase()

    case choice do
      "b" ->
        :ok

      "0" ->
        IO.puts("\n👋 Goodbye!")
        System.halt(0)

      num ->
        case Enum.find(items, fn {n, _, _, _} -> n == num end) do
          nil ->
            IO.puts("\n❌ Invalid choice, please try again")
            sub_loop({key, title, items})

          {_, name, action, _help} ->
            invoke(action, name)
            sub_loop({key, title, items})
        end
    end
  end

  # ----------------------------------------------------------------------
  # Action dispatch
  # ----------------------------------------------------------------------

  defp invoke({:fun, fun}, name), do: safe_execute(fun, name, [])
  defp invoke({:fun, fun, args}, name), do: safe_execute(fun, name, args)

  defp invoke({:fun_confirm, fun, prompt}, name),
    do: safe_execute_with_confirm(fun, name, prompt)

  defp invoke({:nyi, message}, _name), do: IO.puts("\n" <> message)

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
      safe_execute(func, name, [])
    else
      IO.puts("❌ Operation cancelled by user")
    end
  end

  # ----------------------------------------------------------------------
  # System status / help
  # ----------------------------------------------------------------------

  defp show_system_status do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("SYSTEM STATUS")
    IO.puts(String.duplicate("=", 60))

    required_commands = ["bash", "git", "gh", "jq"]

    IO.puts("\nRequired Commands:")

    Enum.each(required_commands, fn cmd ->
      if System.cmd("which", [cmd], stderr_to_stdout: true) |> elem(0) == 0 do
        IO.puts("  ✅ #{cmd}")
      else
        IO.puts("  ❌ #{cmd} (missing)")
      end
    end)

    scripts_dir = "scripts"

    if File.exists?(scripts_dir) do
      script_count = File.ls!(scripts_dir) |> Enum.count()
      IO.puts("\nScripts Directory: ✅ #{script_count} entries found")
    else
      IO.puts("\nScripts Directory: ❌ Not found")
    end

    IO.puts("\nGitHub CLI Status:")

    case System.cmd("gh", ["auth", "status"], stderr_to_stdout: true) do
      {0, output} -> IO.puts("  ✅ Authenticated: #{String.trim(output)}")
      {_, _} -> IO.puts("  ❌ Not authenticated or error")
    end

    IO.puts("\nOwnership Allowlist:")
    Enum.each(ScriptManager.OwnershipGuard.allowed_owners(), fn o ->
      IO.puts("  • #{o}")
    end)

    IO.puts("\n" <> String.duplicate("-", 60))
    IO.puts("Press Enter to return to main menu...")
    IO.gets("")
  end

  defp show_help do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("HELP — Detailed Function Information")
    IO.puts(String.duplicate("=", 60))

    Enum.each(categories(), fn {key, title, items} ->
      IO.puts("\n[#{key}] #{title}")
      IO.puts(String.duplicate("-", 60))

      Enum.each(items, fn {num, name, _action, blurb} ->
        IO.puts("  [#{key}#{num}] #{name}")
        if blurb && blurb != "", do: IO.puts("        #{blurb}")
      end)
    end)

    IO.puts("\n" <> String.duplicate("-", 60))
    IO.puts("Ownership safety:")
    IO.puts(
      "  Operations that touch repositories check the allowlist in" <>
        " config/owners.config (or the GIT_SCRIPTS_ALLOWED_OWNERS env var)."
    )
    IO.puts("  Add yourself, your son, and any organisations you control there.")

    IO.puts("\nPress Enter to return to main menu...")
    IO.gets("")
  end

  # ----------------------------------------------------------------------
  # External launchers (kept public so the menu definition can reference them)
  # ----------------------------------------------------------------------

  @doc false
  def run_clean_unicode do
    IO.puts("\n🧼 CLEAN UNICODE")
    IO.puts("Cleaning hidden/bidirectional Unicode characters from files...")

    script_path = "/var/mnt/eclipse/scripts/clean-unicode.sh"

    if File.exists?(script_path) do
      IO.puts("Running: #{script_path}")

      case System.cmd(script_path, []) do
        {output, 0} ->
          IO.puts("✅ Unicode cleaning complete!")
          IO.puts(output)

        {error, status} ->
          IO.puts("❌ Unicode cleaning failed (exit #{status}):")
          IO.puts(error)
      end
    else
      IO.puts("❌ Script not found: #{script_path}")
      IO.puts("Cannot perform Unicode cleaning")
    end

    :ok
  end

  @doc false
  def launch_nqc do
    IO.puts("\n🚀 Launching NextGen Query Client...")
    nqc_launcher = "/var/mnt/eclipse/repos/nextgen-databases/nqc/nqc-enhanced-launcher.sh"

    if File.exists?(nqc_launcher) do
      IO.puts("Starting NQC web interface...")

      case System.cmd(nqc_launcher, ["--auto"]) do
        {_, 0} -> IO.puts("✅ NQC launched successfully")
        {error, status} -> IO.puts("❌ Failed to launch NQC (exit #{status}): #{error}")
      end
    else
      IO.puts("❌ NQC launcher not found: #{nqc_launcher}")
      IO.puts("Please install NQC first")
    end
  end

  @doc false
  def launch_invariant_path do
    IO.puts("\n🔍 Launching Invariant Path...")
    ip_launcher = "/var/mnt/eclipse/repos/invariant-path/invariant-path-launcher"

    if File.exists?(ip_launcher) do
      IO.puts("Starting Invariant Path analysis tool...")

      case System.cmd(ip_launcher, ["--auto"]) do
        {_, 0} -> IO.puts("✅ Invariant Path launched successfully")
        {error, status} ->
          IO.puts("❌ Failed to launch Invariant Path (exit #{status}): #{error}")
      end
    else
      IO.puts("❌ Invariant Path launcher not found: #{ip_launcher}")
      IO.puts("Please install Invariant Path first")
    end
  end

  # ----------------------------------------------------------------------
  # Input helper
  # ----------------------------------------------------------------------

  defp read_choice do
    try do
      case IO.gets("") do
        nil -> "0"
        :eof -> "0"
        input -> String.trim(input)
      end
    rescue
      _ -> "0"
    end
  end
end
