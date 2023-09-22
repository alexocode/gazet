defmodule Gazet.Message do
  @type data :: term
  @type metadata :: map

  @type t :: %__MODULE__{
          data: data,
          metadata: metadata
        }
  @enforce_keys [:data, :metadata]
  defstruct [:data, :metadata]
end
