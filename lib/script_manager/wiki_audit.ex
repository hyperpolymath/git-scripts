defmodule ScriptManager.WikiAudit do
  @moduledoc "Wiki Audit functionality - checks wiki content for issues"

  @doc "Run wiki audit on repositories"
  def run do
    IO.puts("\n📚 WIKI AUDIT")
    IO.puts("=============")
    IO.puts("Running wiki audit script...")
    
    # Call the actual Bash script
    script_path = "scripts/wiki-audit.sh"
    
    if File.exists?(script_path) do
      IO.puts("Executing: #{script_path}")
      result = System.cmd("bash", [script_path])
      
      case result do
        {0, _output} -> IO.puts("\n✅ Wiki audit completed successfully!")
        {error_code, _output} -> IO.puts("\n❌ Wiki audit failed with code #{error_code}")
      end
    else
      IO.puts("❌ Script not found: #{script_path}")
    end
  end
end