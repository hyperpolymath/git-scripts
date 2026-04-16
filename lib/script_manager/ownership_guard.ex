defmodule ScriptManager.OwnershipGuard do
  @moduledoc """
  Owner allowlist gate for any script that talks to GitHub or pushes to remotes.

  Refuses to act on repositories owned by anyone outside the configured
  allowlist. Mirrors `scripts/lib/ownership_guard.sh` so bash scripts and
  Elixir modules behave the same way.

  Allowlist sources (first non-empty wins):
    1. `GIT_SCRIPTS_ALLOWED_OWNERS` env var (space- or comma-separated).
    2. `config/owners.config` (parsed for the `ALLOWED_OWNERS=( … )` array).
    3. The default `["hyperpolymath"]`.
  """

  @config_paths [
    "config/owners.config",
    "/var/mnt/eclipse/repos/git-scripts/config/owners.config"
  ]

  @default_owners ["hyperpolymath"]

  @doc "Return the configured list of allowed owners (lowercase)."
  @spec allowed_owners() :: [String.t()]
  def allowed_owners do
    raw =
      case System.get_env("GIT_SCRIPTS_ALLOWED_OWNERS") do
        nil -> from_config_file() || @default_owners
        ""  -> from_config_file() || @default_owners
        env -> parse_list(env)
      end

    Enum.map(raw, &String.downcase/1)
  end

  @doc "True when an owner string is in the allowlist."
  @spec owner_allowed?(String.t() | nil) :: boolean()
  def owner_allowed?(nil), do: false
  def owner_allowed?(""), do: false
  def owner_allowed?(owner) when is_binary(owner) do
    String.downcase(owner) in allowed_owners()
  end

  @doc "Get the GitHub owner from a local repo's `origin` remote, or nil."
  @spec repo_owner(String.t()) :: String.t() | nil
  def repo_owner(repo_path) do
    case System.cmd("git", ["-C", repo_path, "config", "--get", "remote.origin.url"],
           stderr_to_stdout: true
         ) do
      {url, 0} -> url |> String.trim() |> parse_owner_from_url()
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @doc "True when the local repo's GitHub owner is in the allowlist."
  @spec repo_allowed?(String.t()) :: boolean()
  def repo_allowed?(repo_path) do
    case repo_owner(repo_path) do
      nil -> false
      owner -> owner_allowed?(owner)
    end
  end

  @doc """
  Filter a list of repo paths down to those whose origin owner is allowed.
  Repos with no GitHub origin are excluded.
  """
  @spec filter_allowed([String.t()]) :: [String.t()]
  def filter_allowed(paths) when is_list(paths) do
    Enum.filter(paths, &repo_allowed?/1)
  end

  @doc """
  Like `filter_allowed/1` but also prints a one-line summary of how many
  repos were rejected, so the user can see the guard at work.
  """
  @spec filter_allowed_verbose([String.t()]) :: [String.t()]
  def filter_allowed_verbose(paths) when is_list(paths) do
    {allowed, rejected} = Enum.split_with(paths, &repo_allowed?/1)

    if rejected != [] do
      IO.puts(
        "🛡  Ownership guard: skipping #{length(rejected)} repo(s) outside allowlist " <>
          "(#{Enum.join(allowed_owners(), ", ")})."
      )
    end

    allowed
  end

  @doc """
  Hard guard. Aborts the running script with a clear message if `owner`
  is not in the allowlist. Use at the top of any operation that targets
  a single org/user (e.g. mass PR labelling).
  """
  @spec assert_owner_allowed!(String.t()) :: :ok | no_return()
  def assert_owner_allowed!(owner) do
    if owner_allowed?(owner) do
      :ok
    else
      IO.puts(:stderr, """

      ❌ REFUSING to operate on owner '#{owner}'.
         This owner is not in the git-scripts allowlist.
         Allowed owners: #{Enum.join(allowed_owners(), ", ")}

         Edit config/owners.config or set GIT_SCRIPTS_ALLOWED_OWNERS=\"owner1 owner2\"
         to change this.
      """)

      System.halt(78)
    end
  end

  # ------------------------------------------------------------------
  # Internals
  # ------------------------------------------------------------------

  # Host-agnostic owner parser. Handles SSH-style (git@host:path) and URL-style
  # (proto://[creds@]host[:port]/path) and treats the second-to-last path
  # segment as the owner — works for GitHub, GitLab, Bitbucket, Gitea,
  # codeberg, self-hosted servers, and so on.
  defp parse_owner_from_url(url) do
    url = String.trim_trailing(url, ".git")

    path_part =
      cond do
        # SSH-style: [user@]host:path
        m = Regex.run(~r{^[^/\s@]+@[^:]+:(.+)$}, url) -> Enum.at(m, 1)
        # URL-style: proto://[creds@]host[:port]/path
        m = Regex.run(~r{^[a-zA-Z]+://[^/]+(/.+)$}, url) -> Enum.at(m, 1)
        true -> nil
      end

    case path_part do
      nil -> nil
      "" -> nil
      pp ->
        pp = pp |> String.trim_leading("/") |> String.trim_trailing("/")
        case String.split(pp, "/") do
          segments when length(segments) >= 2 -> Enum.at(segments, length(segments) - 2)
          _ -> nil
        end
    end
  end

  defp parse_list(str) do
    str
    |> String.split([",", " ", "\n", "\t"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp from_config_file do
    @config_paths
    |> Enum.find_value(fn path ->
      if File.exists?(path), do: parse_config_file(path), else: nil
    end)
  end

  defp parse_config_file(path) do
    case File.read(path) do
      {:ok, contents} ->
        case Regex.run(~r/ALLOWED_OWNERS=\(([^)]*)\)/s, contents) do
          [_, body] ->
            body
            |> String.split([",", " ", "\n", "\t"], trim: true)
            |> Enum.map(&String.trim(&1, "\""))
            |> Enum.map(&String.trim(&1, "'"))
            |> Enum.reject(&(&1 == ""))
            |> Enum.reject(&String.starts_with?(&1, "#"))
            |> case do
              [] -> nil
              owners -> owners
            end

          _ -> nil
        end

      _ -> nil
    end
  end
end
