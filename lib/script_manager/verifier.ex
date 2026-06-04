# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
defmodule ScriptManager.Verifier do
  @moduledoc "Verification functionality"

  def run do
    IO.puts("\n✅ VERIFIER")
    IO.puts("===========")
    ScriptManager.ScriptRunner.run_script("verify.sh")
  end
end
