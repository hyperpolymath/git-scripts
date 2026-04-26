defmodule ScriptManager.ScriptRunner do
  @moduledoc """
  Runs shell scripts from `scripts/` and reports real duration + exit status.

  Scripts that source `scripts/lib/common.sh` honour these env vars (set
  any of them via the third arg of `run_script/3`):

      GS_DRY_RUN=1     no destructive writes
      GS_YES=1         skip confirmation prompts (CI mode)
      GS_LOG_LEVEL=debug|info|warn|error
      GS_PARALLEL=N    bounded parallelism for repo iteration
      GS_REPO_LIST=…   one-repo-per-line filter file
      NO_COLOR=1       disable ANSI in output

  See `scripts/README.adoc` for the full common.sh contract.
  """

  @scripts_dir "scripts"

  @doc """
  Run a script. Backwards-compatible 2-arity form.
  """
  @spec run_script(String.t(), list(String.t())) :: non_neg_integer()
  def run_script(script_name, args \\ []), do: run_script(script_name, args, %{})

  @doc """
  Run a script with an explicit env map. Use this to surface common.sh
  flags (dry-run, log level, parallelism) from TUI menu choices.

  Example: `run_script("audit_contractiles.sh", ["--report"], %{"GS_DRY_RUN" => "1"})`
  """
  @spec run_script(String.t(), list(String.t()), map()) :: non_neg_integer()
  def run_script(script_name, args, env) when is_map(env) do
    script_path = Path.join(@scripts_dir, script_name)

    if !File.exists?(script_path) do
      IO.puts("❌ Script not found: #{script_path}")
      127
    else
      env_list = Enum.map(env, fn {k, v} -> {to_string(k), to_string(v)} end)

      if env_list != [] do
        env_summary =
          env_list
          |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
          |> Enum.join(" ")

        IO.puts("ℹ️  env: #{env_summary}")
      end

      started_at = System.monotonic_time(:millisecond)

      {_out, status} =
        System.cmd("bash", [script_path | args],
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true,
          env: env_list
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

