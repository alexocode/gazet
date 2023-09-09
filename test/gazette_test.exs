defmodule GazetteTest do
  use ExUnit.Case
  doctest Gazette

  test "greets the world" do
    assert Gazette.hello() == :world
  end
end
