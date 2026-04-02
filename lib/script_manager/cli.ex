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