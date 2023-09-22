defmodule Gazet do
  alias Gazet.Adapter

  @type t :: %__MODULE__{
          adapter: adapter,
          name: name,
          topic: topic
        }
  @enforce_keys [:adapter, :name, :topic]
  defstruct [:adapter, :name, :topic]

  @type adapter :: Gazet.Adapter.spec()
  @type name :: atom
  @type topic :: atom | binary

  @type message :: term
  @type metadata :: map

  @spec publish(t, message, metadata) :: :ok | {:error, reason :: any}
  def publish(%__MODULE__{} = gazet, message, metadata) do
    gazet
    |> adapter()
    |> Adapter.publish(message, metadata)
  end

  @spec adapter(t) :: Adapter.spec()
  def adapter(%__MODULE__{adapter: adapter, name: name, topic: topic}) do
    Adapter.spec(adapter,
      name: Module.concat(name, "Adapter"),
      topic: topic
    )
  end
end
