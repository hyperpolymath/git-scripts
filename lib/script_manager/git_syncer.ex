defmodule ScriptManager.GitSyncer do
  @moduledoc """
  Git synchronization logic for the Hyperpolymath estate.
  Fault-tolerant, concurrent, and strictly typed.
  """

  alias ScriptManager.RepoHelper
  alias ScriptManager.OwnershipGuard

  @type sync_status :: String.t()
  @type merge_status :: String.t()
  @type push_results :: String.t()
  @type branch_name :: String.t()

  @doc "Run the global git sync concurrently across the estate"
  @spec run() :: :ok
  def run do
    IO.puts("\n🌐 GLOBAL GIT SYNC (Concurrent Strict Mode)")
    IO.puts("============================================")

    # Ownership guard: never push to repos outside the allowlist.
    all_repos =
      RepoHelper.find_all_repos()
      |> OwnershipGuard.filter_allowed_verbose()

    header = "| Repository | Sync Status | Merge Status | Push Status |"
    separator = "| :--- | :--- | :--- | :--- |"
    
    IO.puts(header)
    IO.puts(separator)
    
    routing_file = Path.join(RepoHelper.routing_dir(), "sync_results.md")
    File.write!(routing_file, "# Global Git Sync Results - #{DateTime.utc_now()}\n\n")
    File.write!(routing_file, "#{header}\n#{separator}\n", [:append])
    
    # Fault Tolerance: Isolate each repo sync in its own task
    all_repos
    |> Task.async_stream(fn path ->
      sync_repo(path, routing_file)
    end, max_concurrency: 5, timeout: 60000)
    |> Enum.each(fn _ -> :ok end)
    
    IO.puts("\n✅ Global Sync Complete")
    :ok
  end

  @spec sync_repo(RepoHelper.path(), String.t()) :: :ok
  defp sync_repo(path, routing_file) do
    repo_name = RepoHelper.repo_name(path)
    
    try do
      # 0. Fetch to know the state of remotes
      System.cmd("git", ["fetch", "--all", "--prune"], cd: path)

      # 1. Sync Local Changes
      sync_status = sync_local_changes(path)
      
      # 2. Merge/Rebase to Main
      {merge_status, current_branch} = merge_to_main(path)
      
      # 3. Establish Tracking and Push
      push_results = if current_branch == "main" or merge_status =~ "Merged" or merge_status =~ "Rebased" do
        establish_tracking(path)
        push_to_remotes(path)
      else
        "Not on main (#{current_branch})"
      end

      row = "| #{repo_name} | #{sync_status} | #{merge_status} | #{push_results} |"
      IO.puts(row)
      # Self-Healing: Use atomic append
      File.write!(routing_file, "#{row}\n", [:append])
    rescue
      e ->
        err_row = "| #{repo_name} | 💥 CRASHED | N/A | #{inspect(e)} |"
        IO.puts(err_row)
        File.write!(routing_file, "#{err_row}\n", [:append])
    end
    :ok
  end

  @spec sync_local_changes(RepoHelper.path()) :: sync_status()
  defp sync_local_changes(path) do
    case System.cmd("git", ["status", "--porcelain"], cd: path) do
      {"", 0} -> "Clean"
      {_, 0} ->
        System.cmd("git", ["add", "."], cd: path)
        case System.cmd("git", ["commit", "-m", "chore: automated sync of local changes"], cd: path) do
          {_, 0} -> "Synced"
          _ -> "Sync Fail"
        end
      _ -> "Status Fail"
    end
  end

  @spec merge_to_main(RepoHelper.path()) :: {merge_status(), branch_name()}
  defp merge_to_main(path) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], cd: path) do
      {branch, 0} ->
        branch = String.trim(branch)
        if branch == "main" do
          # On main, try to rebase with origin/main if it exists
          if has_remote_branch?(path, "origin", "main") do
            case System.cmd("git", ["rebase", "origin/main"], cd: path) do
              {_, 0} -> {"Rebased with origin/main", "main"}
              _ -> 
                System.cmd("git", ["rebase", "--abort"], cd: path)
                {"REBASE_CONFLICT", "main"}
            end
          else
            {"Already Main", "main"}
          end
        else
          if has_branch?(path, "main") do
            case System.cmd("git", ["checkout", "main"], cd: path) do
              {_, 0} ->
                # Try to rebase first if it has an upstream
                if has_remote_branch?(path, "origin", "main") do
                  System.cmd("git", ["rebase", "origin/main"], cd: path)
                end

                case System.cmd("git", ["merge", branch, "-m", "chore: merge #{branch} into main"], cd: path) do
                  {_, 0} -> {"Merged #{branch}", "main"}
                  _ ->
                    System.cmd("git", ["merge", "--abort"], cd: path)
                    System.cmd("git", ["checkout", branch], cd: path)
                    {"MERGE_CONFLICT", branch}
                end
              _ -> {"Checkout Fail", branch}
            end
          else
            {"No Main", branch}
          end
        end
      _ -> {"GIT_ERROR", ""}
    end
  end

  @spec has_branch?(RepoHelper.path(), String.t()) :: boolean()
  defp has_branch?(path, branch) do
    match?({_, 0}, System.cmd("git", ["show-ref", "--verify", "--quiet", "refs/heads/#{branch}"], cd: path))
  end

  @spec has_remote_branch?(RepoHelper.path(), String.t(), String.t()) :: boolean()
  defp has_remote_branch?(path, remote, branch) do
    match?({_, 0}, System.cmd("git", ["show-ref", "--verify", "--quiet", "refs/remotes/#{remote}/#{branch}"], cd: path))
  end

  @spec establish_tracking(RepoHelper.path()) :: :ok
  defp establish_tracking(path) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "main@{u}"], cd: path) do
      {_, 0} -> :ok
      _ ->
        if has_remote_branch?(path, "origin", "main") do
          System.cmd("git", ["branch", "--set-upstream-to=origin/main", "main"], cd: path)
        end
        :ok
    end
  end

  @spec push_to_remotes(RepoHelper.path()) :: push_results()
  defp push_to_remotes(path) do
    case System.cmd("git", ["remote"], cd: path) do
      {"", 0} -> "No remotes"
      {remotes_str, 0} ->
        remotes = String.split(remotes_str)
        results = Enum.map(remotes, fn remote ->
          # Use --force-with-lease for safer negotiation
          case System.cmd("git", ["push", remote, "main", "--force-with-lease"], cd: path) do
            {_, 0} -> "#{remote}:OK"
            {out, _} -> 
              short_err = out |> String.split("\n") |> List.first() |> String.slice(0..30)
              "#{remote}:FAIL(#{short_err})"
          end
        end)
        Enum.join(results, " ")
      _ -> "Remote Error"
    end
  end
end
