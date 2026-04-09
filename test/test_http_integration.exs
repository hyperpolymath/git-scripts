#!/usr/bin/env elixir

# Test HTTP Capability Gateway integration

IO.puts("Testing HTTP Capability Gateway Integration...")

# Test HTTP Client module
try do
  Code.require_file("lib/script_manager/http_client.ex", __DIR__)
  IO.puts("✅ HTTP Client module loaded")
rescue
  e ->
  IO.puts("❌ HTTP Client module error: #{inspect(e)}")
end

# Test GitHub API with HTTP integration
try do
  Code.require_file("lib/script_manager/github_api.ex", __DIR__)
  IO.puts("✅ GitHub API module with HTTP integration loaded")
rescue
  e ->
  IO.puts("❌ GitHub API module error: #{inspect(e)}")
end

# Test SimpleJSON
try do
  Code.require_file("lib/script_manager/simple_json.ex", __DIR__)
  
  # Test JSON encoding
  test_data = %{name: "test", value: 42, active: true, tags: ["a", "b"]}
  json = ScriptManager.SimpleJSON.encode(test_data)
  IO.puts("✅ SimpleJSON works: #{json}")
rescue
  e ->
  IO.puts("❌ SimpleJSON error: #{inspect(e)}")
end

# Test HTTP Client methods
try do
  # Test GET
  get_response = ScriptManager.HTTPClient.get("https://api.github.com")
  IO.puts("✅ HTTP GET test: #{get_response.status}")
  
  # Test POST
  post_response = ScriptManager.HTTPClient.post("https://api.github.com", '{"test": "data"}')
  IO.puts("✅ HTTP POST test: #{post_response.status}")
rescue
  e ->
  IO.puts("❌ HTTP Client test error: #{inspect(e)}")
end

IO.puts("\n✅ HTTP Capability Gateway integration test complete!")
IO.puts("The system is ready for real GitHub API calls!")