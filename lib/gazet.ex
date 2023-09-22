defmodule Gazet do
  alias Gazet.Adapter
  alias Gazet.Message

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

  @spec publish(t, message :: Message.data(), metadata :: Message.metadata()) ::
          :ok | {:error, reason :: any}
  def publish(%__MODULE__{} = gazet, message, metadata) do
    gazet
    |> adapter()
    |> Adapter.publish(%Message{data: message, metadata: metadata})
  end

  @spec adapter(t) :: Adapter.spec()
  def adapter(%__MODULE__{adapter: adapter, name: name, topic: topic}) do
    Adapter.spec(adapter,
      name: Module.concat(name, "Adapter"),
      topic: topic
    )
  end
end
