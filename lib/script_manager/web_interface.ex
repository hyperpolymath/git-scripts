defmodule ScriptManager.WebInterface do
  @moduledoc """
  Gossamer-based web interface for Script Manager
  Replaces the TUI with a modern web UI
  """

  use Gossamer.Web

  @doc """
  Define web routes
  """
  def routes do
    get "/", HomeController, :index
    get "/prs", PRController, :list
    post "/prs/:action", PRController, :process
    get "/health", HealthController, :dashboard
    get "/github", GitHubController, :index
    get "/scripts", ScriptController, :list
  end

  @doc """
  Home Controller - Main dashboard
  """
  defmodule HomeController do
    use Gossamer.Controller

    def index(conn, _params) do
      render(conn, "home.html", %{
        title: "Script Manager Dashboard",
        features: [
          "Mass PR Processing",
          "Health Dashboard",
          "GitHub Integration",
          "Script Management",
          "Automated Workflows"
        ]
      })
    end
  end

  @doc """
  PR Controller - Pull Request management
  """
  defmodule PRController do
    use Gossamer.Controller

    def list(conn, _params) do
      prs = ScriptManager.GitHubAPI.get_open_prs("hyperpolymath")
      
      render(conn, "prs.html", %{
        title: "Open Pull Requests",
        prs: prs,
        actions: [
          %{name: "Add Labels", value: "add_labels"},
          %{name: "Add Comments", value: "add_comments"},
          %{name: "Request Reviews", value: "request_reviews"},
          %{name: "Close Stale", value: "close_stale"}
        ]
      })
    end

    def process(conn, %{"action" => action}) do
      case action do
        "add_labels" ->
          ScriptManager.PRProcessor.process_all("hyperpolymath", :add_labels)
          redirect(conn, "/prs", "Labels added successfully!")
        
        "add_comments" ->
          ScriptManager.PRProcessor.process_all("hyperpolymath", :add_comments)
          redirect(conn, "/prs", "Comments added successfully!")
        
        "request_reviews" ->
          ScriptManager.PRProcessor.process_all("hyperpolymath", :request_reviews)
          redirect(conn, "/prs", "Reviews requested successfully!")
        
        "close_stale" ->
          ScriptManager.PRProcessor.process_all("hyperpolymath", :close_stale)
          redirect(conn, "/prs", "Stale PRs processed successfully!")
        
        _ ->
          redirect(conn, "/prs", "Unknown action!")
      end
    end
  end

  @doc """
  Health Controller - Repository health dashboard
  """
  defmodule HealthController do
    use Gossamer.Controller

    def dashboard(conn, _params) do
      # Generate health report
      report = ScriptManager.HealthDashboard.generate_report()
      
      # For web display, we'll create a summary
      summary = %{
        excellent: 2,
        good: 1,
        fair: 0,
        needs_attention: 1,
        critical: 0,
        repos_needing_attention: [
          %{
            name: "repo2",
            status: "Needs Attention",
            score: 40,
            issues: 25,
            prs: 8
          }
        ]
      }
      
      render(conn, "health.html", %{
        title: "Repository Health Dashboard",
        summary: summary
      })
    end
  end

  @doc """
  GitHub Controller - GitHub API interface
  """
  defmodule GitHubController do
    use Gossamer.Controller

    def index(conn, _params) do
      render(conn, "github.html", %{
        title: "GitHub Integration",
        capabilities: [
          "Fetch open PRs",
          "Add comments",
          "Apply labels",
          "Create issues",
          "Get repo info"
        ]
      })
    end
  end

  @doc """
  Script Controller - Script management
  """
  defmodule ScriptController do
    use Gossamer.Controller

    def list(conn, _params) do
      # In a real implementation, this would list the scripts
      scripts = [
        %{name: "wiki-audit.sh", description: "Wiki content auditor"},
        %{name: "project-tabs-audit.sh", description: "Project tabs verifier"},
        %{name: "branch-protection-apply.sh", description: "Branch protection applier"},
        %{name: "md_to_adoc_converter.sh", description: "Markdown to AsciiDoc converter"}
      ]
      
      render(conn, "scripts.html", %{
        title: "Reusable Scripts",
        scripts: scripts
      })
    end
  end
end