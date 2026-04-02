defmodule ScriptManager.WebApp do
  @moduledoc """
  Main web application entry point
  Starts the Gossamer web server
  """

  @doc """
  Start the web application
  """
  def start do
    IO.puts("🌐 Starting Script Manager Web Interface...")
    IO.puts("======================================")
    
    # Start Gossamer web server
    port = 4000
    
    Gossamer.start(
      port: port,
      routes: ScriptManager.WebInterface.routes(),
      static_dir: "priv/static",
      template_dir: "priv/templates"
    )
    
    IO.puts("✅ Web interface started on http://localhost:#{port}")
    IO.puts("Press Ctrl+C to stop")
  end

  @doc """
  Create necessary directories
  """
  def ensure_directories do
    File.mkdir_p("priv/static")
    File.mkdir_p("priv/templates")
    File.mkdir_p("reports")
  end
end