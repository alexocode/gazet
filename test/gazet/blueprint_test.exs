defmodule Gazet.BlueprintTest do
  use ExUnit.Case, async: true

  alias Gazet.Blueprint
  alias Gazet.Test.Blueprints.{BehaviourStruct, UsingStruct, UsingStructWithTypespecForAnything}

  describe "build/2" do
    test "returns an error when the given module doesn't implement the Blueprint behaviour" do
      assert {:error, {:no_blueprint, __MODULE__}} = Blueprint.build(__MODULE__, [])
    end

    test "builds the struct when the module implements the behaviour" do
      ref = make_ref()

      assert {:ok, struct} = Blueprint.build(BehaviourStruct, ref)
      assert struct == %BehaviourStruct{value: ref}
    end

    test "builds the struct when the module uses Gazet.Blueprint" do
      number = :rand.uniform(1_000_000)
      string = "some string"
      anything = make_ref()
      values = [number: number, string: string, anything: anything]

      assert {:ok, struct} = Blueprint.build(UsingStruct, values)
      assert struct == %UsingStruct{number: number, string: string, anything: anything}

      assert {:ok, struct} = Blueprint.build(UsingStructWithTypespecForAnything, values)

      assert struct == %UsingStructWithTypespecForAnything{
               number: number,
               string: string,
               anything: anything
             }
    end

    test "returns an error when a required parameter is missing" do
      values = []

      assert {:error, reason} = Blueprint.build(UsingStruct, values)
      assert_validation_error_for(reason, schema: UsingStruct.schema(), values: values)
    end

    test "returns an error when a parameter has the wrong type" do
      values = [number: "not a number"]

      assert {:error, reason} = Blueprint.build(UsingStruct, values)
      assert_validation_error_for(reason, schema: UsingStruct.schema(), values: values)

      values = [number: 42, string: :an_atom]

      assert {:error, reason} = Blueprint.build(UsingStruct, values)
      assert_validation_error_for(reason, schema: UsingStruct.schema(), values: values)
    end
  end

  describe "use/1" do
    test "generates no field typespecs by default" do
      refute has_type(UsingStruct, :number)
      refute has_type(UsingStruct, :string)
      refute has_type(UsingStruct, :anything)

      # Always generated
      assert has_type(UsingStruct, :blueprint)
    end

    test "includes the typespecs that are requested through :typespecs_for" do
      refute has_type(UsingStructWithTypespecForAnything, :number)
      refute has_type(UsingStructWithTypespecForAnything, :string)
      assert has_type(UsingStructWithTypespecForAnything, :anything)

      # Always generated
      assert has_type(UsingStructWithTypespecForAnything, :blueprint)
    end
  end

  defp assert_validation_error_for(reason, schema: schema, values: values) do
    assert Gazet.Options.validate(values, schema) == {:error, reason}
  end

  defp has_type(module, type) do
    case Code.Typespec.fetch_types(module) do
      :error ->
        flunk("Cannot fetch types for module: " <> inspect(module))

      {:ok, types} ->
        Enum.any?(types, fn {_, {name, _, _}} -> name == type end)
    end
  end
end
