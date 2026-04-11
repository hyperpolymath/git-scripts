defmodule ScriptManager.MassDeployer do
  @moduledoc "Mass deploy contractiles, K9-SVC, accessibility docs, and VPAT across the entire Hyperpolymath estate (non-interactive)."

  def run do
    IO.puts("\n🚀 MASS DEPLOY (entire estate)")
    IO.puts("===============================")
    ScriptManager.ScriptRunner.run_script("mass_deploy.sh")
  end
end
