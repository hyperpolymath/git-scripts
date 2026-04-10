defmodule ScriptManager.BranchProtection do
  @moduledoc "Branch protection functionality"

  def run do
    IO.puts("\n🔒 BRANCH PROTECTION")
    IO.puts("====================")

    dry_run = confirm("Run in --dry-run mode? [Y/n]: ", true)

    if dry_run || confirm("Apply live branch protection changes? [y/N]: ", false) do
      args = if dry_run, do: ["--dry-run"], else: []
      ScriptManager.ScriptRunner.run_script("branch-protection-apply.sh", args)
    else
      IO.puts("Cancelled.")
    end
  end

  defp confirm(prompt, default) do
    answer =
      case IO.gets(prompt) do
        nil -> ""
        value -> value
      end
      |> String.trim()
      |> String.downcase()

    case answer do
      "" -> default
      "y" -> true
      "yes" -> true
      "n" -> false
      "no" -> false
      _ -> default
    end
  end
end
