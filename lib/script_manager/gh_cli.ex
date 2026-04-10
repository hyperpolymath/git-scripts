defmodule ScriptManager.GHCLI do
  @moduledoc "GitHub CLI functionality"

  def run do
    IO.puts("\n🐙 GITHUB CLI")
    IO.puts("=============")
    ScriptManager.ScriptRunner.run_script("USE-GH-CLI.sh")
  end
end
