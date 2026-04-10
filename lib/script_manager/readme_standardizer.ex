defmodule ScriptManager.ReadmeStandardizer do
  @moduledoc "Standardize READMEs"

  def run do
    IO.puts("\n📖 STANDARDIZE READMES")
    IO.puts("======================")
    ScriptManager.ScriptRunner.run_script("standardize_readmes.sh")
  end
end
