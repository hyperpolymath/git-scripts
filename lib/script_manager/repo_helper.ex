defmodule ScriptManager.RepoHelper do
  @moduledoc """
  Helper functions for local repository management.
  Reflective and strictly typed for the Hyperpolymath Aerie estate.
  """

  @type path :: String.t()
  @type repo_name :: String.t()

  @repos_root "/var/mnt/eclipse/repos"
  @routing_dir "/var/mnt/eclipse/repo-routing"

  @doc "Find all git repositories in the repos root"
  @spec find_all_repos() :: [path()]
  def find_all_repos do
    # Reflective: find directories containing a .git folder.
    Path.wildcard("#{@repos_root}/**/.git", match_dot: true)
    |> Enum.map(&Path.dirname/1)
    |> Enum.reject(fn path ->
      # Fault Tolerance: filter out .git directories inside .git (like modules)
      # and ensure we don't pick up the repos root itself.
      String.contains?(path, "/.git/") or path == @repos_root
    end)
    |> Enum.sort()
  end

  @doc "Get the name of a repository from its path"
  @spec repo_name(path()) :: repo_name()
  def repo_name(path), do: Path.basename(path)

  @doc "Get the repos root"
  @spec repos_root() :: path()
  def repos_root, do: @repos_root

  @doc "Get the routing directory"
  @spec routing_dir() :: path()
  def routing_dir, do: @routing_dir
  
  @doc "Check if a path is a valid repository (reflective check)"
  @spec is_repo?(path()) :: boolean()
  def is_repo?(path), do: File.dir?(Path.join(path, ".git"))
end
