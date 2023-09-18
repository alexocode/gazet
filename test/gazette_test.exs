defmodule GazetTest do
  use ExUnit.Case
  doctest Gazet

  test "greets the world" do
    assert Gazet.hello() == :world
  end
end
