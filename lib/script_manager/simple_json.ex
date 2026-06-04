# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
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