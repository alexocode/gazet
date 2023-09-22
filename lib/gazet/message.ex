defmodule Gazet.Message do
  @type data :: term
  @type metadata :: map

  @type t :: %__MODULE__{
          topic: Gazet.topic(),
          data: data,
          metadata: metadata
        }
  @enforce_keys [:topic, :data, :metadata]
  defstruct [:topic, :data, :metadata]
end
