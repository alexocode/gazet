defmodule Gazet.Test.Blueprints.BehaviourStruct do
  @behaviour Gazet.Blueprint

  defstruct [:value]

  @impl true
  def __blueprint__(value) do
    {:ok, %__MODULE__{value: value}}
  end
end

schema = [
  number: [type: :integer, required: true],
  string: [type: :string],
  anything: [type: :any]
]

defmodule Gazet.Test.Blueprints.UsingStruct do
  use Gazet.Blueprint,
    schema: schema

  def schema, do: unquote(schema)
end

defmodule Gazet.Test.Blueprints.UsingStructWithTypespecForAnything do
  use Gazet.Blueprint,
    schema: schema,
    typespecs_for: [:anything]

  def schema, do: unquote(schema)
end
