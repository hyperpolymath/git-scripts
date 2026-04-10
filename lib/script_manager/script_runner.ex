defmodule ScriptManager.ScriptRunner do
  @moduledoc """
  Runs shell scripts from `scripts/` and reports real duration + exit status.
  """

  @scripts_dir "scripts"

  @spec run_script(String.t(), list(String.t())) :: non_neg_integer()
  def run_script(script_name, args \\ []) do
    script_path = Path.join(@scripts_dir, script_name)

    if !File.exists?(script_path) do
      IO.puts("❌ Script not found: #{script_path}")
      127
    else
      started_at = System.monotonic_time(:millisecond)

      {_out, status} =
        System.cmd("bash", [script_path | args],
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true
        )

      elapsed_ms = System.monotonic_time(:millisecond) - started_at
      elapsed_s = elapsed_ms / 1000

      case status do
        0 -> IO.puts("\n✅ Completed in #{Float.round(elapsed_s, 2)}s")
        _ -> IO.puts("\n❌ Failed (exit #{status}) after #{Float.round(elapsed_s, 2)}s")
      end

      status
    end
  end
end

