defmodule Gazet.EnvTest do
  use ExUnit.Case, async: false

  import Gazet.Test.EnvHelpers

  alias Gazet.Env

  describe "resolve/1" do
    test "merges all env config into one big list" do
      ref = make_ref()

      with_env([key1: [some: "value"], key2: [some_ref: ref]], fn ->
        assert Env.resolve([
                 {:gazet, :key1},
                 {:gazet, :key2}
               ]) == [some: "value", some_ref: ref]
      end)
    end

    test "merges and overwrites env in the order given" do
      with_env([key1: [some: "value"], key2: [some: "new value", another: "value"]], fn ->
        assert Env.resolve([
                 {:gazet, :key1},
                 {:gazet, :key2}
               ]) == [some: "new value", another: "value"]
      end)
    end

    test "treats non-existing env as an empty list" do
      with_env([key1: [some: "value"]], fn ->
        assert Env.resolve([
                 {:gazet, :key1},
                 {:gazet, :key2}
               ]) == [some: "value"]
      end)
    end

    test "allows to pass a single env-tuple instead of a list and only fetches the env for that tuple" do
      with_env([key1: [some: "value"]], fn ->
        assert Env.resolve({:gazet, :key1}) == [some: "value"]
      end)
    end
  end

  describe "resolve/2" do
    test "only returns the given keys from the env" do
      with_env([my_config: [key1: "value1", key2: "value2"]], fn ->
        assert Env.resolve({:gazet, :my_config}, [:key1]) == [key1: "value1"]
      end)

      with_env(
        [my_config: [key1: "value1", key2: "value2"], another_config: [key3: "value3"]],
        fn ->
          assert Env.resolve(
                   [
                     {:gazet, :my_config},
                     {:gazet, :another_config}
                   ],
                   [:key1, :key3]
                 ) == [key1: "value1", key3: "value3"]
        end
      )
    end
  end
end
