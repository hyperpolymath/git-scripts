defmodule ScriptManager.Verifier do
  @moduledoc "Verification functionality"

  def run do
    IO.puts("\n✅ VERIFIER")
    IO.puts("===========")
    ScriptManager.ScriptRunner.run_script("verify.sh")
  end
end
