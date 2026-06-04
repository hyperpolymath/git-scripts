# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
defmodule ScriptManager.MDConverter do
  @moduledoc "MD to ADOC converter"

  def run do
    IO.puts("\n📄 MD TO ADOC CONVERTER")
    IO.puts("=======================")
    ScriptManager.ScriptRunner.run_script("md_to_adoc_converter.sh")
  end
end
