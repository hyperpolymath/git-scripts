# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# lib/script_manager/web_interface.ex
# Gossamer-based web interface for Script Manager.
#
# NOTE: The Gossamer Elixir web bindings are not yet published as a Hex
# package. This module stubs the interface so the project compiles; once
# the gossamer Hex package is available, replace the stubs with
# `use Gossamer.Web` / `use Gossamer.Controller`.

defmodule ScriptManager.WebInterface do
  @moduledoc """
  Gossamer-based web interface for Script Manager.

  Replaces the TUI with a modern web UI. Full implementation pending
  Gossamer Elixir package availability.
  """

  @doc """
  Define web routes.

  Routes delegate to sub-controllers defined below.
  """
  def routes do
    [
      {:get,  "/",         ScriptManager.WebInterface.HomeController,   :index},
      {:get,  "/prs",      ScriptManager.WebInterface.PRController,     :list},
      {:post, "/prs/:action", ScriptManager.WebInterface.PRController,  :process},
      {:get,  "/health",   ScriptManager.WebInterface.HealthController, :dashboard},
      {:get,  "/github",   ScriptManager.WebInterface.GitHubController, :index},
      {:get,  "/scripts",  ScriptManager.WebInterface.ScriptController, :list},
    ]
  end
end

defmodule ScriptManager.WebInterface.HomeController do
  @moduledoc "Home Controller — main dashboard."

  def index(_conn, _params) do
    %{
      title: "Script Manager Dashboard",
      features: [
        "Mass PR Processing",
        "Health Dashboard",
        "GitHub Integration",
        "Script Management",
        "Automated Workflows"
      ]
    }
  end
end

defmodule ScriptManager.WebInterface.PRController do
  @moduledoc "PR Controller — pull request management."

  def list(_conn, _params) do
    prs = ScriptManager.GitHubAPI.get_open_prs("hyperpolymath")
    %{
      title: "Open Pull Requests",
      prs: prs,
      actions: [
        %{name: "Add Labels",       value: "add_labels"},
        %{name: "Add Comments",     value: "add_comments"},
        %{name: "Request Reviews",  value: "request_reviews"},
        %{name: "Close Stale",      value: "close_stale"}
      ]
    }
  end

  def process(_conn, %{"action" => action}) do
    case action do
      "add_labels"      -> ScriptManager.PRProcessor.process_all("hyperpolymath", :add_labels)
      "add_comments"    -> ScriptManager.PRProcessor.process_all("hyperpolymath", :add_comments)
      "request_reviews" -> ScriptManager.PRProcessor.process_all("hyperpolymath", :request_reviews)
      "close_stale"     -> ScriptManager.PRProcessor.process_all("hyperpolymath", :close_stale)
      _                 -> {:error, :unknown_action}
    end
  end
end

defmodule ScriptManager.WebInterface.HealthController do
  @moduledoc "Health Controller — repository health dashboard."

  def dashboard(_conn, _params) do
    %{
      title: "Repository Health Dashboard",
      summary: %{
        excellent:               2,
        good:                    1,
        fair:                    0,
        needs_attention:         1,
        critical:                0,
        repos_needing_attention: [
          %{name: "repo2", status: "Needs Attention", score: 40, issues: 25, prs: 8}
        ]
      }
    }
  end
end

defmodule ScriptManager.WebInterface.GitHubController do
  @moduledoc "GitHub Controller — GitHub API interface."

  def index(_conn, _params) do
    %{
      title: "GitHub Integration",
      capabilities: [
        "Fetch open PRs",
        "Add comments",
        "Apply labels",
        "Create issues",
        "Get repo info"
      ]
    }
  end
end

defmodule ScriptManager.WebInterface.ScriptController do
  @moduledoc "Script Controller — script management."

  def list(_conn, _params) do
    scripts = [
      %{name: "wiki-audit.sh",              description: "Wiki content auditor"},
      %{name: "project-tabs-audit.sh",      description: "Project tabs verifier"},
      %{name: "branch-protection-apply.sh", description: "Branch protection applier"},
      %{name: "md_to_adoc_converter.sh",    description: "Markdown to AsciiDoc converter"}
    ]
    %{title: "Reusable Scripts", scripts: scripts}
  end
end
