defmodule ScriptManager.SimpleJSON do
  @moduledoc """
  Simple JSON encoder for basic data structures
  """

  @doc """
  Encode a term to JSON string
  """
  def encode(term) when is_map(term) do
    pairs = Enum.map(term, fn {k, v} -> "\"#{k}\":#{encode(v)}" end)
    "{" <> Enum.join(pairs, ",") <> "}"
  end

  def encode(term) when is_list(term) do
    items = Enum.map(term, &encode/1)
    "[" <> Enum.join(items, ",") <> "]"
  end

  def encode(term) when is_binary(term) do
    "\"#{term}\""
  end

  def encode(term) when is_integer(term) or is_float(term) do
    to_string(term)
  end

  def encode(term) when is_boolean(term) do
    if term, do: "true", else: "false"
  end

  def encode(nil), do: "null"

  def encode(_term), do: "null"
end