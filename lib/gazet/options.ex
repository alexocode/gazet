defmodule Gazet.Options do
  @moduledoc """
  Functions to validate config against a given schema.

  Relies on `NimbleOptions`. If `NimbleOptions` isn't installed it falls back
  to a minimal implementation where it checks the presence of expected keys.
  """

  if Code.ensure_loaded?(NimbleOptions) do
    @implementation __MODULE__.NimbleOptions
  else
    @implementation __MODULE__.Fallback
  end

  @type schema :: term
  @type error :: @implementation.error()

  @callback schema!(keyword) :: schema
  @callback docs(schema) :: String.t()
  @callback map(schema, mapper :: (field :: atom, spec :: keyword -> mapped)) :: list(mapped)
            when mapped: term
  @callback typespec(schema) :: Macro.t()
  @callback typespec(schema, field :: atom) :: Macro.t()
  @callback validate(config, schema) :: {:ok, config} | {:error, reason :: term}
            when config: keyword
  @callback validate!(config, schema) :: config | no_return when config: keyword

  defdelegate schema!(keyword), to: @implementation
  defdelegate map(schema, mapper), to: @implementation
  defdelegate docs(schema), to: @implementation
  defdelegate typespec(schema), to: @implementation
  defdelegate typespec(schema, field), to: @implementation
  defdelegate validate(config, schema), to: @implementation
  defdelegate validate!(config, schema), to: @implementation
end
