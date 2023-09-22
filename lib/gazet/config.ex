defmodule Gazet.Config do
  @moduledoc """
  Functions to validate config against a given schema.

  Relies on `NimbleOptions`. If `NimbleOptions` isn't installed it falls back
  to a minimal implementation where it checks the presence of expected keys.
  """

  @type schema :: term

  @callback schema!(keyword) :: schema
  @callback docs(schema) :: String.t()
  @callback validate(config, schema) :: {:ok, config} | {:error, reason :: term}
            when config: keyword
  @callback validate!(config, schema) :: config | no_return when config: keyword

  if Code.loaded?(__MODULE__.NimbleOptions) do
    @implementation __MODULE__.NimbleOptions
  else
    @implementation __MODULE__.Fallback
  end

  defdelegate schema!(keyword), to: @implementation
  defdelegate docs(schema), to: @implementation
  defdelegate validate(config, schema), to: @implementation
  defdelegate validate!(config, schema), to: @implementation
end
