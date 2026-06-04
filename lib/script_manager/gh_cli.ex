# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
defmodule ScriptManager.GHCLI do
  @moduledoc "GitHub CLI functionality"

  def run do
    IO.puts("\n🐙 GITHUB CLI")
    IO.puts("=============")
    ScriptManager.ScriptRunner.run_script("USE-GH-CLI.sh")
  end
end
