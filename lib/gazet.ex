defmodule Gazet do
  alias Gazet.Adapter

  @type t :: %__MODULE__{
          adapter: adapter,
          topic: topic
        }
  defstruct [:adapter, :topic]

  @type adapter :: Gazet.Adapter.spec()
  @type topic :: atom | binary

  @type message :: term
  @type metadata :: map

  @spec publish(t, message, metadata) :: :ok | {:error, reason :: any}
  def publish(%__MODULE__{} = gazet, message, metadata) do
    Adapter.publish(gazet.adapter, gazet.topi, message, metadata)
  end
end
