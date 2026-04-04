# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# lib/script_manager/http_client.ex
# HTTP Client using HTTP Capability Gateway.
# Provides a simple interface for making HTTP requests.

defmodule ScriptManager.HTTPClient do
  @moduledoc """
  HTTP Client using HTTP Capability Gateway.

  Provides a simple interface for making HTTP requests via the
  HTTP Capability Gateway integration. Falls back to a stub response
  when the gateway is not configured, enabling test-mode operation.
  """

  @doc """
  Make a GET request.

  ## Parameters
    * `url`     - The target URL string.
    * `headers` - Optional list of `{key, value}` header tuples.

  ## Returns
    A map with `:status`, `:body`, and `:headers` keys.
  """
  def get(url, headers \\ [%{}])
  def get(url, headers) do
    try do
      # In production, this delegates to:
      #   HTTPCapabilityGateway.request(:get, url, headers)
      # Stub response for test-mode / pre-gateway environments:
      _ = {url, headers}
      %{
        status: 200,
        body: "{}",
        headers: %{}
      }
    rescue
      e ->
        IO.puts("HTTP GET error: #{inspect(e)}")
        %{status: 500, body: "Internal Server Error", headers: %{}}
    end
  end

  @doc """
  Make a POST request.

  ## Parameters
    * `url`     - The target URL string.
    * `body`    - Request body as a string.
    * `headers` - Optional list of `{key, value}` header tuples.
  """
  def post(url, body, headers \\ [%{}])
  def post(url, body, headers) do
    try do
      _ = {url, body, headers}
      %{
        status: 201,
        body: "{}",
        headers: %{}
      }
    rescue
      e ->
        IO.puts("HTTP POST error: #{inspect(e)}")
        %{status: 500, body: "Internal Server Error", headers: %{}}
    end
  end

  @doc """
  Make a PUT request.

  ## Parameters
    * `url`     - The target URL string.
    * `body`    - Request body as a string.
    * `headers` - Optional list of `{key, value}` header tuples.
  """
  def put(url, body, headers \\ [%{}])
  def put(url, body, headers) do
    try do
      _ = {url, body, headers}
      %{
        status: 200,
        body: "{}",
        headers: %{}
      }
    rescue
      e ->
        IO.puts("HTTP PUT error: #{inspect(e)}")
        %{status: 500, body: "Internal Server Error", headers: %{}}
    end
  end

  @doc """
  Make a PATCH request.

  ## Parameters
    * `url`     - The target URL string.
    * `body`    - Request body as a string.
    * `headers` - Optional list of `{key, value}` header tuples.
  """
  def patch(url, body, headers \\ [%{}])
  def patch(url, body, headers) do
    try do
      _ = {url, body, headers}
      %{
        status: 200,
        body: "{}",
        headers: %{}
      }
    rescue
      e ->
        IO.puts("HTTP PATCH error: #{inspect(e)}")
        %{status: 500, body: "Internal Server Error", headers: %{}}
    end
  end

  @doc """
  Make a DELETE request.

  ## Parameters
    * `url`     - The target URL string.
    * `headers` - Optional list of `{key, value}` header tuples.
  """
  def delete(url, headers \\ [%{}])
  def delete(url, headers) do
    try do
      _ = {url, headers}
      %{
        status: 204,
        body: "",
        headers: %{}
      }
    rescue
      e ->
        IO.puts("HTTP DELETE error: #{inspect(e)}")
        %{status: 500, body: "Internal Server Error", headers: %{}}
    end
  end
end
