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
      # {:tesla, "~> 1.4"},      # HTTP client - replaced by HTTP Capability Gateway
      # {:jason, "~> 1.2"},       # JSON parser - replaced by SimpleJSON
      # {:poison, "~> 5.0"},     # JSON library - replaced by SimpleJSON
      # {:sweet_xml, "~> 0.7"},  # XML parsing
      # {:ex2ms, "~> 1.6"}       # Excel generation
      {:http_capability_gateway, git: "https://github.com/hyperpolymath/http-capability-gateway.git", runtime: false},
      # gossamer is a Rust/multi-lang project — Elixir bindings not yet published
      # {:gossamer, git: "https://github.com/hyperpolymath/gossamer.git"},
      {:stream_data, "~> 1.0", only: :test}  # Property-based testing
    ]
  end
end
