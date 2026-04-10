defmodule ScriptManager.WikiAudit do
  @moduledoc "Wiki Audit functionality - checks wiki content for issues"

  @doc "Run wiki audit on repositories"
  def run do
    IO.puts("\n📚 WIKI AUDIT")
    IO.puts("=============")
    ScriptManager.ScriptRunner.run_script("wiki-audit.sh")
  end
end
