defmodule ScriptManager.HealthDashboard do
  @moduledoc """
  Repository health dashboard and reporting (simplified version)
  """

  @doc """
  Generate comprehensive health report for all repositories
  """
  def generate_report() do
    IO.puts("\n🏥 REPOSITORY HEALTH DASHBOARD")
    IO.puts("================================")
    
    # Simplified version with sample data
    # In production, this would fetch real data from GitHub API
    
    sample_repos = [
      %{
        name: "repo1",
        stars: 120,
        forks: 35,
        open_issues: 8,
        open_prs: 3,
        updated_at: "2024-01-25T10:30:00Z"
      },
      %{
        name: "repo2",
        stars: 45,
        forks: 12,
        open_issues: 25,
        open_prs: 8,
        updated_at: "2023-12-15T09:15:00Z"
      },
      %{
        name: "repo3",
        stars: 200,
        forks: 78,
        open_issues: 2,
        open_prs: 1,
        updated_at: "2024-01-30T14:45:00Z"
      }
    ]
    
    IO.puts("Analyzing #{length(sample_repos)} sample repositories...")
    
    report = Enum.map(sample_repos, fn repo ->
      health_score = calculate_health_score(repo)
      
      %{
        name: repo.name,
        stars: repo.stars,
        forks: repo.forks,
        open_issues: repo.open_issues,
        open_prs: repo.open_prs,
        updated_at: repo.updated_at,
        health_score: health_score,
        status: health_status(health_score)
      }
    end)
    
    generate_summary(report)
    
    # Save report using our simple JSON encoder
    save_report(report)
    
    IO.puts("\n✅ Health report generated!")
    IO.puts("Report saved to: reports/health_report_#{DateTime.utc_now() |> DateTime.to_date()}.json")
  end

  defp calculate_health_score(repo) do
    # Enhanced scoring algorithm with multiple factors
    
    # 1. Issue Management (30% weight)
    issue_ratio = repo.open_issues / max(repo.stars, 1) * 10
    issue_score = cond do
      issue_ratio > 5 -> 1    # Too many issues per star
      issue_ratio > 2 -> 3    # Moderate issues
      true -> 5              # Good issue management
    end
    
    # 2. PR Management (25% weight)
    pr_score = cond do
      repo.open_prs > 15 -> 1    # Too many open PRs
      repo.open_prs > 8 -> 3     # Moderate PRs
      true -> 5                # Good PR management
    end
    
    # 3. Activity/Recency (20% weight)
    updated_recently = case DateTime.from_iso8601(repo.updated_at) do
      {:ok, updated_date, _offset} ->
        days_ago = DateTime.diff(DateTime.utc_now(), updated_date, :day)
        days_ago <= 30
      _ ->
        false
    end
    
    activity_score = cond do
      updated_recently -> 5      # Recently active
      repo.open_issues > 0 -> 3  # Some activity
      true -> 1                 # Inactive
    end
    
    # 4. Community Engagement (15% weight)
    engagement_ratio = repo.forks / max(repo.stars, 1)
    engagement_score = cond do
      engagement_ratio > 0.5 -> 5  # High engagement
      engagement_ratio > 0.2 -> 3  # Moderate engagement
      true -> 1                 # Low engagement
    end
    
    # 5. Maintenance Burden (10% weight)
    maintenance_score = cond do
      repo.open_issues + repo.open_prs > 30 -> 1  # High burden
      repo.open_issues + repo.open_prs > 15 -> 3  # Moderate burden
      true -> 5                                # Low burden
    end
    
    # Weighted average (weights sum to 100%)
    weighted_score = trunc(
      (issue_score * 0.30) +
      (pr_score * 0.25) +
      (activity_score * 0.20) +
      (engagement_score * 0.15) +
      (maintenance_score * 0.10)
    )
    
    # Scale to 0-100 range
    weighted_score * 20
  end

  defp health_status(score) do
    cond do
      score >= 90 -> "Excellent"
      score >= 70 -> "Good"
      score >= 50 -> "Fair"
      score >= 30 -> "Needs Attention"
      true -> "Critical"
    end
  end

  defp generate_summary(report) do
    IO.puts("\n=== HEALTH SUMMARY ===")
    
    excellent = Enum.count(report, &(&1.status == "Excellent"))
    good = Enum.count(report, &(&1.status == "Good"))
    fair = Enum.count(report, &(&1.status == "Fair"))
    needs_attention = Enum.count(report, &(&1.status == "Needs Attention"))
    critical = Enum.count(report, &(&1.status == "Critical"))
    
    IO.puts("Excellent: #{excellent}")
    IO.puts("Good: #{good}")
    IO.puts("Fair: #{fair}")
    IO.puts("Needs Attention: #{needs_attention}")
    IO.puts("Critical: #{critical}")
    
    # Show repos needing attention
    if needs_attention + critical > 0 do
      IO.puts("\n=== REPOSITORIES NEEDING ATTENTION ===")
      Enum.each(report, fn repo ->
        if repo.status in ["Needs Attention", "Critical"] do
          IO.puts("#{repo.name}: #{repo.status} (Score: #{repo.health_score})")
          IO.puts("  Issues: #{repo.open_issues}, PRs: #{repo.open_prs}")
        end
      end)
    end
  end

  defp save_report(report) do
    # Create reports directory
    File.mkdir_p("reports")
    
    # Generate filename
    date = DateTime.utc_now() |> DateTime.to_date() |> to_string()
    filename = "reports/health_report_#{date}.json"
    
    # Save as JSON (using our simple JSON encoder)
    File.write!(filename, ScriptManager.SimpleJSON.encode(report))
    
    filename
  end
end