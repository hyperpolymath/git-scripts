defmodule ScriptManager.BatchDeployer do
  @moduledoc "Deploy contractiles, K9-SVC, accessibility docs, and VPAT across repositories in interactive batches of 30."

  def run do
    IO.puts("\n📦 BATCH DEPLOY (using EstateDeployer)")
    IO.puts("===============================")
    # EstateDeployer doesn't have an interactive batch-of-30 yet, but we'll 
    # point it to its run function for now.
    ScriptManager.EstateDeployer.deploy(:all, [:contractiles, :k9_svc, :accessibility, :vpat, :pre_commit])
  end
end
