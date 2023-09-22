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
    gazet.adapter
    |> Adapter.spec(name: gazet.name, topic: gazet.topic)
    |> Adapter.publish(message, metadata)
  end
end
