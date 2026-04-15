defmodule ScriptManager.MassDeployer do
  @moduledoc "Mass deploy contractiles, K9-SVC, accessibility docs, and VPAT across the entire Hyperpolymath estate (non-interactive)."

  def run do
    IO.puts("\n🚀 MASS DEPLOY (using EstateDeployer)")
    IO.puts("===============================")
    ScriptManager.EstateDeployer.deploy(:all, [:contractiles, :k9_svc, :accessibility, :vpat, :pre_commit])
  end
end
