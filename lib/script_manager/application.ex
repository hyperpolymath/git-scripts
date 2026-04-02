defmodule ScriptManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Ensure directories exist
    ScriptManager.WebApp.ensure_directories()
    
    children = [
      # Start the web interface when the application starts
      {Task, fn -> ScriptManager.WebApp.start() end}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ScriptManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
