# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
defmodule ScriptManager.ReadmeStandardizer do
  @moduledoc "Standardize READMEs"

  def run do
    IO.puts("\n📖 STANDARDIZE READMES")
    IO.puts("======================")
    ScriptManager.ScriptRunner.run_script("standardize_readmes.sh")
  end
end
