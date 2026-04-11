defmodule ScriptManager.TUI do
  @moduledoc "Elixir TUI for managing reusable scripts and functions"

  @doc "Main TUI loop"
  def run do
    IO.puts("\n🔧 ELIXIR SCRIPT MANAGER")
    IO.puts("========================")
    
    menu()
  end

  defp menu do
    loop()
  end
  
  defp loop do
    IO.puts("\n[1] Wiki Audit")
    IO.puts("[2] Project Tabs Audit")
    IO.puts("[3] Branch Protection Apply")
    IO.puts("[4] MD to ADOC Converter")
    IO.puts("[5] Standardize READMEs")
    IO.puts("[6] Update Repos")
    IO.puts("[7] Audit Scripts")
    IO.puts("[8] Verify")
    IO.puts("[9] Use GH CLI")
    IO.puts("[10] Mass PR Processor")
    IO.puts("[11] Health Dashboard")
    IO.puts("[12] Repository Cleanup")
    IO.puts("[13] Clean Unicode")
    IO.puts("[14] Dependency Updater")
    IO.puts("[15] Release Manager")
    IO.puts("[16] Contractile Audit")
    IO.puts("[17] Batch Deploy (30 at a time)")
    IO.puts("[18] Mass Deploy (entire estate)")
    IO.puts("[0] Exit")
    
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
      "1" -> 
        ScriptManager.WikiAudit.run()
        loop()
      "2" -> 
        ScriptManager.ProjectTabsAudit.run()
        loop()
      "3" -> 
        ScriptManager.BranchProtection.run()
        loop()
      "4" -> 
        ScriptManager.MDConverter.run()
        loop()
      "5" -> 
        ScriptManager.ReadmeStandardizer.run()
        loop()
      "6" -> 
        ScriptManager.RepoUpdater.run()
        loop()
      "7" -> 
        ScriptManager.ScriptAuditor.run()
        loop()
      "8" -> 
        ScriptManager.Verifier.run()
        loop()
      "9" -> 
        ScriptManager.GHCLI.run()
        loop()
      "10" -> 
        ScriptManager.PRProcessor.process_all("hyperpolymath", :add_labels)
        loop()
      "11" -> 
        ScriptManager.HealthDashboard.generate_report()
        loop()
      "12" -> 
        ScriptManager.RepoCleanup.run()
        loop()
      "13" -> 
        run_clean_unicode()
        loop()
      "14" -> 
        IO.puts("\n📦 Dependency Updater - Coming Soon!")
        loop()
      "15" ->
        IO.puts("\n🎉 Release Manager - Coming Soon!")
        loop()
      "16" ->
        ScriptManager.ContractileAuditor.run()
        loop()
      "17" ->
        ScriptManager.BatchDeployer.run()
        loop()
      "18" ->
        ScriptManager.MassDeployer.run()
        loop()
      "0" -> IO.puts("\nGoodbye!")
      _ -> 
        IO.puts("\nInvalid choice, please try again")
        loop()
    end
  end

  defp run_clean_unicode do
    IO.puts("\n🧼 CLEAN UNICODE")
    IO.puts("Cleaning hidden/bidirectional Unicode characters from files...")
    
    # Execute the clean-unicode script
    result = System.cmd("/var/mnt/eclipse/scripts/clean-unicode.sh", [])
    
    IO.puts("✅ Unicode cleaning complete!")
    :ok
  end
end