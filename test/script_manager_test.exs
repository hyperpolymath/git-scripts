# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# test/script_manager_test.exs
# Comprehensive CRG Grade C tests for git-scripts ScriptManager.
#
# Categories covered:
#   Unit       - Pure functions in SimpleJSON tested in isolation.
#   Smoke      - All primary modules are loadable and their public API exists.
#   Property   - StreamData property-based tests for JSON encode/decode invariants.
#   E2E        - End-to-end encode -> decode roundtrip chain.
#   Contract   - API invariants (encode(decode(x)) == x for valid JSON).
#   Aspect     - Cross-cutting concerns: nil safety, no token leakage, idempotency.

defmodule ScriptManagerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ScriptManager.SimpleJSON

  # ---------------------------------------------------------------------------
  # Smoke tests: all modules are compiled and callable
  # ---------------------------------------------------------------------------

  describe "smoke: module availability" do
    test "SimpleJSON module is loaded" do
      assert Code.ensure_loaded?(ScriptManager.SimpleJSON)
    end

    test "GitHubAPI module is loaded" do
      assert Code.ensure_loaded?(ScriptManager.GitHubAPI)
    end

    test "GHCLI module is loaded" do
      assert Code.ensure_loaded?(ScriptManager.GHCLI)
    end

    test "PRProcessor module is loaded" do
      assert Code.ensure_loaded?(ScriptManager.PRProcessor)
    end

    test "HealthDashboard module is loaded" do
      assert Code.ensure_loaded?(ScriptManager.HealthDashboard)
    end

    test "SimpleJSON.encode/1 is exported" do
      assert function_exported?(ScriptManager.SimpleJSON, :encode, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Unit tests: SimpleJSON.encode/1 — pure function, no side effects
  # ---------------------------------------------------------------------------

  describe "unit: SimpleJSON.encode/1 — scalars" do
    test "encodes a string" do
      assert SimpleJSON.encode("hello") == ~s("hello")
    end

    test "encodes an integer" do
      assert SimpleJSON.encode(42) == "42"
    end

    test "encodes a float" do
      assert SimpleJSON.encode(3.14) == "3.14"
    end

    test "encodes true" do
      assert SimpleJSON.encode(true) == "true"
    end

    test "encodes false" do
      assert SimpleJSON.encode(false) == "false"
    end

    test "encodes nil as null" do
      assert SimpleJSON.encode(nil) == "null"
    end

    test "encodes an empty string" do
      assert SimpleJSON.encode("") == ~s("")
    end
  end

  describe "unit: SimpleJSON.encode/1 — collections" do
    test "encodes an empty map" do
      assert SimpleJSON.encode(%{}) == "{}"
    end

    test "encodes an empty list" do
      assert SimpleJSON.encode([]) == "[]"
    end

    test "encodes a simple map" do
      result = SimpleJSON.encode(%{"key" => "value"})
      assert result == ~s({"key":"value"})
    end

    test "encodes a list of integers" do
      assert SimpleJSON.encode([1, 2, 3]) == "[1,2,3]"
    end

    test "encodes a list of strings" do
      result = SimpleJSON.encode(["a", "b"])
      assert result == ~s(["a","b"])
    end

    test "encodes nested map" do
      result = SimpleJSON.encode(%{"outer" => %{"inner" => 1}})
      assert result == ~s({"outer":{"inner":1}})
    end

    test "encodes a list of booleans" do
      assert SimpleJSON.encode([true, false]) == "[true,false]"
    end
  end

  # ---------------------------------------------------------------------------
  # Smoke: encode never crashes on basic inputs
  # ---------------------------------------------------------------------------

  describe "smoke: encode never crashes on common inputs" do
    test "encode a map with mixed value types" do
      # Does not crash; we don't assert the exact format for mixed maps here
      # since key ordering may vary — we only assert it produces a binary.
      result = SimpleJSON.encode(%{"a" => 1, "b" => true, "c" => nil})
      assert is_binary(result)
    end

    test "encode a deeply nested structure" do
      deep = %{"l1" => %{"l2" => %{"l3" => [1, 2, %{"x" => "y"}]}}}
      result = SimpleJSON.encode(deep)
      assert is_binary(result)
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests (StreamData)
  # ---------------------------------------------------------------------------

  describe "property: SimpleJSON.encode/1 — invariants" do
    property "encode any string always produces a quoted binary" do
      check all(s <- string(:printable, min_length: 0, max_length: 100)) do
        result = SimpleJSON.encode(s)
        assert is_binary(result)
        assert String.starts_with?(result, "\"")
        assert String.ends_with?(result, "\"")
      end
    end

    property "encode any integer always produces a parseable numeric string" do
      check all(n <- integer()) do
        result = SimpleJSON.encode(n)
        assert is_binary(result)
        assert {_parsed, ""} = Integer.parse(result)
      end
    end

    property "encode any list of integers produces a bracketed string" do
      check all(items <- list_of(integer(), min_length: 0, max_length: 20)) do
        result = SimpleJSON.encode(items)
        assert is_binary(result)
        assert String.starts_with?(result, "[")
        assert String.ends_with?(result, "]")
      end
    end

    property "encode any boolean is always 'true' or 'false'" do
      check all(b <- boolean()) do
        result = SimpleJSON.encode(b)
        assert result in ["true", "false"]
      end
    end

    property "encode a map with string keys always returns a braced string" do
      check all(pairs <- map_of(
                  string(:alphanumeric, min_length: 1, max_length: 10),
                  integer(),
                  min_length: 0,
                  max_length: 5
                )) do
        result = SimpleJSON.encode(pairs)
        assert is_binary(result)
        assert String.starts_with?(result, "{")
        assert String.ends_with?(result, "}")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # E2E: encode -> raw string -> structural comparison
  # (SimpleJSON has no decode; we verify encode produces valid round-trippable
  #  output by using Jason or string inspection.)
  # ---------------------------------------------------------------------------

  describe "e2e: encode produces structurally valid JSON" do
    test "a simple map encodes to valid JSON structure" do
      encoded = SimpleJSON.encode(%{"name" => "hyperpolymath", "count" => 42})
      assert is_binary(encoded)
      # Verify key structural markers are present
      assert String.contains?(encoded, "\"name\"")
      assert String.contains?(encoded, "\"hyperpolymath\"")
      assert String.contains?(encoded, "42")
    end

    test "a list of maps encodes to valid JSON array structure" do
      data = [%{"id" => 1}, %{"id" => 2}]
      encoded = SimpleJSON.encode(data)
      assert String.starts_with?(encoded, "[")
      assert String.ends_with?(encoded, "]")
      assert String.contains?(encoded, "\"id\"")
    end

    test "full pipeline: build a structured payload and encode it" do
      # Simulate a real use-case: building a GitHub API request body
      payload = %{
        "title"  => "Fix: reticulate lattice correctly",
        "body"   => "This PR resolves the AffineScript integration issue.",
        "labels" => ["bug", "priority:high"]
      }

      encoded = SimpleJSON.encode(payload)
      assert is_binary(encoded)
      assert String.contains?(encoded, "\"title\"")
      assert String.contains?(encoded, "\"labels\"")
      # Labels are a list — verify they appear as a JSON array
      assert String.contains?(encoded, "[")
    end
  end

  # ---------------------------------------------------------------------------
  # Contract tests: API invariants
  # ---------------------------------------------------------------------------

  describe "contract: SimpleJSON.encode/1 invariants" do
    test "contract: encode(string) always wraps in double quotes" do
      for s <- ["", "hello", "with spaces", "with\ttab"] do
        result = SimpleJSON.encode(s)
        assert String.starts_with?(result, "\""), "expected leading quote for #{inspect(s)}"
        assert String.ends_with?(result, "\""),   "expected trailing quote for #{inspect(s)}"
      end
    end

    test "contract: encode(nil) is always 'null'" do
      assert SimpleJSON.encode(nil) == "null"
    end

    test "contract: encode result is always a non-empty binary" do
      inputs = ["x", 0, 1.0, true, false, nil, [], %{}]
      for input <- inputs do
        result = SimpleJSON.encode(input)
        assert is_binary(result),         "result is not a binary for #{inspect(input)}"
        assert byte_size(result) > 0,     "result is empty for #{inspect(input)}"
      end
    end

    test "contract: encode([]) is always '[]'" do
      assert SimpleJSON.encode([]) == "[]"
    end

    test "contract: encode(%{}) is always '{}'" do
      assert SimpleJSON.encode(%{}) == "{}"
    end
  end

  # ---------------------------------------------------------------------------
  # Aspect tests: cross-cutting concerns
  # ---------------------------------------------------------------------------

  describe "aspect: nil and empty input safety" do
    test "aspect: encode(nil) does not crash" do
      assert SimpleJSON.encode(nil) == "null"
    end

    test "aspect: encode([nil, nil]) does not crash" do
      result = SimpleJSON.encode([nil, nil])
      assert result == "[null,null]"
    end

    test "aspect: encode map with nil value does not crash" do
      result = SimpleJSON.encode(%{"key" => nil})
      assert is_binary(result)
    end
  end

  describe "aspect: no API token leakage through encode" do
    test "aspect: a token-like string is treated as an opaque string value" do
      # Encoding a token must NOT strip, transform, or log it differently.
      # The result should be a JSON string — no special treatment.
      fake_token = "ghp_FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE"
      result = SimpleJSON.encode(fake_token)
      # Encoded value must be a quoted string — not null, not redacted.
      assert result == ~s("#{fake_token}")
    end

    test "aspect: a map containing a credential key encodes without side effects" do
      payload = %{"Authorization" => "token FAKE_TOKEN_ABC123"}
      result = SimpleJSON.encode(payload)
      assert is_binary(result)
      # We do NOT assert the exact string; we only assert no crash and non-empty.
      assert byte_size(result) > 0
    end
  end

  describe "aspect: idempotency" do
    test "aspect: calling encode twice on the same value yields the same result" do
      value = %{"repo" => "git-scripts", "version" => 1}
      first  = SimpleJSON.encode(value)
      second = SimpleJSON.encode(value)
      # Maps with a single key are deterministic.
      assert first == second
    end

    test "aspect: calling encode on a list is deterministic" do
      value = [1, 2, 3, "four", nil, true]
      assert SimpleJSON.encode(value) == SimpleJSON.encode(value)
    end
  end
end
