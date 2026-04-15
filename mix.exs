defmodule ScriptManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :script_manager,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      escript: escript_config(),
      deps: deps()
    ]
  end

  defp escript_config do
    [
      main_module: ScriptManager.CLI,
      # Build to a separate artifact path so launcher can atomically
      # promote it into ./script_manager after validation.
      path: "_build/script_manager.escript"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ScriptManager.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},       # JSON parser
      {:req, "~> 0.5"},         # HTTP client
      {:http_capability_gateway, git: "https://github.com/hyperpolymath/http-capability-gateway.git", runtime: false},
      {:stream_data, "~> 1.0", only: :test}  # Property-based testing
    ]
  end
end
