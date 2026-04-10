defmodule ScriptManager.ProjectTabsAudit do
  @moduledoc "Project Tabs Audit - checks GitHub project tabs configuration"

  @doc "Audit project tabs across repositories"
  def run do
    IO.puts("\n🏗️ PROJECT TABS AUDIT")
    IO.puts("=====================")
    ScriptManager.ScriptRunner.run_script("project-tabs-audit.sh")
  end
end
