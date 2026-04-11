defmodule ScriptManager.BatchDeployer do
  @moduledoc "Deploy contractiles, K9-SVC, accessibility docs, and VPAT across repositories in interactive batches of 30."

  def run do
    IO.puts("\n📦 BATCH DEPLOY (30 at a time)")
    IO.puts("===============================")
    ScriptManager.ScriptRunner.run_script("batch_deploy_30.sh")
  end
end
