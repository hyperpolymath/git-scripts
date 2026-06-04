# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
defmodule ScriptManager.CLI do
  @moduledoc "
  Command-line interface for the script manager
  "

  @doc "
  Main entry point
  "
  def main(_args) do
    ScriptManager.TUI.run()
  end
end