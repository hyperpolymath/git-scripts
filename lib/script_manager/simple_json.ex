defmodule ScriptManager.SimpleJSON do
  @moduledoc """
  Simple JSON encoder for basic data structures
  """

  @doc """
  Encode a term to JSON string
  """
  def encode(term) do
    Jason.encode!(term)
  end

  @doc """
  Decode a JSON string to a term
  """
  def decode(string) do
    Jason.decode!(string)
  end
end