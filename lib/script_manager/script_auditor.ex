defmodule ScriptManager.ScriptAuditor do
  @moduledoc "Audit scripts"

  def run do
    IO.puts("\n🔍 SCRIPT AUDITOR")
    IO.puts("=================")
    ScriptManager.ScriptRunner.run_script("audit_script.sh")
  end
end
