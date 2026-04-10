defmodule ScriptManager.RepoUpdater do
  @moduledoc "Update repositories"

  def run do
    IO.puts("\n🔄 UPDATE REPOS")
    IO.puts("===============")
    IO.puts("⚠️  This may commit and force-push across repositories.")

    if confirm("Type 'UPDATE' to continue: ", "UPDATE") do
      ScriptManager.ScriptRunner.run_script("update_repos.sh")
    else
      IO.puts("Cancelled.")
    end
  end

  defp confirm(prompt, expected) do
    answer =
      case IO.gets(prompt) do
        nil -> ""
        value -> value
      end
      |> String.trim()

    answer == expected
  end
end
