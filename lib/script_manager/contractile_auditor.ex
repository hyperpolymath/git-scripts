defmodule ScriptManager.ContractileAuditor do
  @moduledoc "Audit contractile completeness, K9-SVC integration, and accessibility across the Hyperpolymath estate."

  def run do
    IO.puts("\n🔍 CONTRACTILE AUDIT")
    IO.puts("====================")
    ScriptManager.ScriptRunner.run_script("audit_contractiles.sh")
  end
end
