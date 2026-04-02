defmodule ScriptManager.GitHubAPI do
  @moduledoc """
  GitHub API client for repository management using HTTP Capability Gateway
  """

  @base_url "https://api.github.com"
  @token Application.compile_env(:script_manager, :github)[:token]

  @doc """
  Get all open pull requests for an organization
  """
  def get_open_prs(org) do
    try do
      # Get all repositories for the organization
      repos_response = get_repositories(org)
      
      case repos_response do
        %{status: 200, body: body} ->
          repos = SimpleJSON.decode(body)
          
          # Get open PRs for each repository
          Enum.flat_map(repos, fn repo ->
            get_open_prs_for_repo(org, repo["name"])
          end)
        
        _ ->
          IO.puts("Error fetching repositories")
          []
      end
    rescue
      e ->
        IO.puts("Error in get_open_prs: #{inspect(e)}")
        []
    end
  end

  defp get_repositories(org) do
    url = "#{@base_url}/orgs/#{org}/repos?per_page=100"
    headers = [
      {"Authorization", "token #{@token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "ElixirScriptManager/1.0"}
    ]
    
    ScriptManager.HTTPClient.get(url, headers)
  end

  defp get_open_prs_for_repo(org, repo) do
    url = "#{@base_url}/repos/#{org}/#{repo}/pulls?state=open&per_page=100"
    headers = [
      {"Authorization", "token #{@token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "ElixirScriptManager/1.0"}
    ]
    
    response = ScriptManager.HTTPClient.get(url, headers)
    
    case response do
      %{status: 200, body: body} ->
        prs = SimpleJSON.decode(body)
        
        Enum.map(prs, fn pr ->
          %{
            repo: repo,
            number: pr["number"],
            title: pr["title"],
            url: pr["html_url"],
            created_at: pr["created_at"],
            updated_at: pr["updated_at"]
          }
        end)
      
      _ ->
        IO.puts("Error fetching PRs for #{repo}")
        []
    end
  end

  @doc """
  Add a comment to a pull request
  """
  def add_comment(org, repo, pr_number, comment) do
    url = "#{@base_url}/repos/#{org}/#{repo}/issues/#{pr_number}/comments"
    headers = [
      {"Authorization", "token #{@token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "ElixirScriptManager/1.0"}
    ]
    body = SimpleJSON.encode(%{"body" => comment})
    
    response = ScriptManager.HTTPClient.post(url, body, headers)
    
    case response do
      %{status: 201} -> :ok
      _ -> :error
    end
  end

  @doc """
  Apply labels to a pull request
  """
  def apply_labels(org, repo, pr_number, labels) do
    url = "#{@base_url}/repos/#{org}/#{repo}/issues/#{pr_number}/labels"
    headers = [
      {"Authorization", "token #{@token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "ElixirScriptManager/1.0"}
    ]
    body = SimpleJSON.encode(%{"labels" => labels})
    
    response = ScriptManager.HTTPClient.post(url, body, headers)
    
    case response do
      %{status: 200} -> :ok
      _ -> :error
    end
  end

  @doc """
  Get repository information
  """
  def get_repo_info(org, repo) do
    url = "#{@base_url}/repos/#{org}/#{repo}"
    headers = [
      {"Authorization", "token #{@token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "ElixirScriptManager/1.0"}
    ]
    
    response = ScriptManager.HTTPClient.get(url, headers)
    
    case response do
      %{status: 200, body: body} -> SimpleJSON.decode(body)
      _ -> %{}
    end
  end

  @doc """
  Create a new issue
  """
  def create_issue(org, repo, title, body) do
    url = "#{@base_url}/repos/#{org}/#{repo}/issues"
    headers = [
      {"Authorization", "token #{@token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "ElixirScriptManager/1.0"}
    ]
    request_body = SimpleJSON.encode(%{"title" => title, "body" => body})
    
    response = ScriptManager.HTTPClient.post(url, request_body, headers)
    
    case response do
      %{status: 201, body: body} -> SimpleJSON.decode(body)
      _ -> :error
    end
  end
end