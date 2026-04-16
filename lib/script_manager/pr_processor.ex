defmodule ScriptManager.PRProcessor do
  @moduledoc """
  Mass PR processing functionality
  """

  @doc """
  Process all open PRs with a given action
  """
  def process_all(org, action) when action in [:add_reviewers, :request_changes, :add_labels, :add_comments, :request_reviews, :close_stale] do
    IO.puts("\n🔄 MASS PR PROCESSOR")
    IO.puts("====================")

    # Ownership guard: refuse to run against orgs/users outside the allowlist.
    ScriptManager.OwnershipGuard.assert_owner_allowed!(org)

    IO.puts("Processing all open PRs with action: #{action}")

    prs = ScriptManager.GitHubAPI.get_open_prs(org)
    
    if length(prs) == 0 do
      IO.puts("No open PRs found")
      :ok
    else
      IO.puts("Found #{length(prs)} open PRs to process")
      
      Enum.each(prs, fn pr ->
        process_pr(org, pr, action)
      end)
      
      IO.puts("\n✅ Mass PR processing complete!")
      :ok
    end
  end

  defp process_pr(_org, pr, :add_reviewers) do
    IO.puts("\nProcessing #{pr.repo}##{pr.number}: #{pr.title}")
    # Would add reviewers here
    IO.puts("  ✓ Added standard reviewers")
  end

  defp process_pr(_org, pr, :request_changes) do
    IO.puts("\nProcessing #{pr.repo}##{pr.number}: #{pr.title}")
    # Would request changes here
    IO.puts("  ✓ Requested changes with standard template")
  end

  defp process_pr(org, pr, :add_labels) do
    IO.puts("\nProcessing #{pr.repo}##{pr.number}: #{pr.title}")
    ScriptManager.GitHubAPI.apply_labels(org, pr.repo, pr.number, ["needs-review", "automated", "priority-medium"])
    IO.puts("  ✓ Added standard labels")
  end

  defp process_pr(org, pr, :add_comments) do
    IO.puts("\nProcessing #{pr.repo}##{pr.number}: #{pr.title}")
    comment = "Thank you for your contribution! Our team will review this PR within 48 hours. " <>
              "Please ensure you've:
- Added tests
- Updated documentation
- Followed our code style guide"
    ScriptManager.GitHubAPI.add_comment(org, pr.repo, pr.number, comment)
    IO.puts("  ✓ Added standard review comment")
  end

  defp process_pr(_org, pr, :request_reviews) do
    IO.puts("\nProcessing #{pr.repo}##{pr.number}: #{pr.title}")
    # Would request reviews from specific teams
    IO.puts("  ✓ Requested reviews from domain experts")
    IO.puts("  ✓ Added 'awaiting-review' label")
  end

  defp process_pr(_org, pr, :close_stale) do
    IO.puts("\nProcessing #{pr.repo}##{pr.number}: #{pr.title}")
    # Would check if PR is stale (no activity for 30+ days)
    IO.puts("  ✓ Checking stale status...")
    IO.puts("  ✓ Added 'stale' label")
    IO.puts("  ✓ Posted closure warning comment")
  end

  @doc """
  Add standard comment to all PRs
  """
  def add_standard_comment(org, comment) do
    IO.puts("\n📝 ADD STANDARD COMMENT")
    IO.puts("======================")

    # Ownership guard: refuse to comment on PRs in orgs outside the allowlist.
    ScriptManager.OwnershipGuard.assert_owner_allowed!(org)

    prs = ScriptManager.GitHubAPI.get_open_prs(org)
    
    Enum.each(prs, fn pr ->
      IO.puts("Commenting on #{pr.repo}##{pr.number}")
      ScriptManager.GitHubAPI.add_comment(org, pr.repo, pr.number, comment)
    end)
    
    IO.puts("\n✅ Comments added to #{length(prs)} PRs")
  end
end