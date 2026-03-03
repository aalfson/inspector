defmodule InspectorTest do
  use ExUnit.Case
  doctest Inspector

  test "greets the world" do
    assert Inspector.hello() == :world
  end
end
