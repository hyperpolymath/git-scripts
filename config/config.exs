import Config

# GitHub API Configuration
config :script_manager, :github,
  api_url: "https://api.github.com",
  token: System.get_env("GITHUB_TOKEN"),
  org: "hyperpolymath",
  per_page: 100

# HTTP Client Configuration
config :tesla, :adapter, Tesla.Adapter.Hackney

# Application Configuration
config :script_manager,
  report_dir: "reports",
  max_concurrent: 10,
  timeout: 30_000
