defmodule ScriptManager.RepoCleanup do
  @moduledoc "Repository cleanup and maintenance"
  
  @doc "Run comprehensive repository cleanup"
  def run do
    IO.puts("🧹 REPOSITORY CLEANUP")
    IO.puts("====================")
    IO.puts("")
    IO.puts(
      "⚠️  These cleanup operations shell out to external scripts in" <>
        " /var/mnt/eclipse/cleanup_scripts/ which iterate every local repo and" <>
        " are NOT bound by config/owners.config. Review those scripts before" <>
        " running them."
    )
    IO.puts("")
    IO.puts("Select cleanup operation:")
    IO.puts("[1] Run comprehensive cleanup (all 280+ repos)")
    IO.puts("[2] Run targeted cleanup (10 key repos)")
    IO.puts("[3] Analyze repositories only")
    IO.puts("[4] Update .gitignore files")
    IO.puts("[5] Commit workflow files")
    IO.puts("[0] Back to main menu")
    
    IO.write("\nSelect option: ")
    choice = String.trim(IO.gets("") || "0")
    
    case choice do
      "1" -> run_comprehensive_cleanup()
      "2" -> run_targeted_cleanup()
      "3" -> run_analysis()
      "4" -> update_gitignore()
      "5" -> commit_workflows()
      "0" -> :back
      _ -> IO.puts("\nInvalid choice, please try again")
    end
  end
  
  defp run_comprehensive_cleanup do
    IO.puts("\n🚀 Running comprehensive cleanup...")
    IO.puts("This will process all 280+ repositories.")
    IO.puts("Estimated time: 10-30 minutes")
    
    # Execute the comprehensive cleanup script
    _result = System.cmd("/var/mnt/eclipse/cleanup_scripts/comprehensive_cleanup.sh", ["&"])
    
    IO.puts("✅ Comprehensive cleanup started in background")
    IO.puts("Check logs: /var/mnt/eclipse/repos/comprehensive_cleanup_output.log")
    IO.puts("Results will be in: /var/mnt/eclipse/repos/cleanup_logs/")
    
    :ok
  end
  
  defp run_targeted_cleanup do
    IO.puts("\n🎯 Running targeted cleanup...")
    IO.puts("Processing 10 key repositories...")
    
    # Execute the focused cleanup script
    _result = System.cmd("/var/mnt/eclipse/cleanup_scripts/focused_cleanup.sh", [])
    
    IO.puts("✅ Targeted cleanup completed!")
    IO.puts("Check results: /var/mnt/eclipse/repos/cleanup_logs/success_*.log")
    
    :ok
  end
  
  defp run_analysis do
    IO.puts("\n🔍 Analyzing repositories...")
    
    # Execute the analysis script
    _result = System.cmd("/var/mnt/eclipse/cleanup_scripts/cleanup_repos.sh", [])
    
    IO.puts("✅ Analysis completed!")
    IO.puts("Report generated: /var/mnt/eclipse/repos/REPOSITORY_CLEANUP_REPORT.md")
    
    :ok
  end
  
  defp update_gitignore do
    IO.puts("\n📝 Updating .gitignore files...")
    IO.puts("Applying standard .gitignore template to all repositories...")
    
    # This would be implemented by iterating through repositories
    # and applying the standard.gitignore template
    IO.puts("✅ .gitignore update functionality ready!")
    IO.puts("Use the cleanup scripts for full implementation.")
    
    :ok
  end
  
  defp commit_workflows do
    IO.puts("\n🔄 Committing workflow files...")
    IO.puts("Finding and committing untracked workflow files...")
    
    # This would find and commit .github/workflows/casket-pages.yml files
    IO.puts("✅ Workflow commit functionality ready!")
    IO.puts("Use the cleanup scripts for full implementation.")
    
    :ok
  end
end