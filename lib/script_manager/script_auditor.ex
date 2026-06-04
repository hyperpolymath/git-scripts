# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
defmodule ScriptManager.ScriptAuditor do
  @moduledoc "Audit scripts"

  def run do
    IO.puts("\n🔍 SCRIPT AUDITOR")
    IO.puts("=================")
    ScriptManager.ScriptRunner.run_script("audit_script.sh")
  end
end
