defmodule ScriptManagerTest do
  use ExUnit.Case
  doctest ScriptManager

  test "greets the world" do
    assert ScriptManager.hello() == :world
  end
end
