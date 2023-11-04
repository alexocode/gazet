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
  @callback raw(schema) :: keyword

  @callback docs(schema) :: String.t()
  @callback typespec(schema) :: Macro.t()
  @callback typespec(schema, field :: atom) :: Macro.t()
  @callback validate(config, schema) :: {:ok, config} | {:error, reason :: term}
            when config: keyword
  @callback validate!(config, schema) :: config | no_return when config: keyword

  # coveralls-ignore-next-line
  defdelegate schema!(keyword), to: @implementation

  @doc """
  Returns the original schema definition passed to `schema!/1`.

  ## Examples

      iex> raw_schema = [some_field: [type: :string, required: true]]
      iex> schema = schema!(raw_schema)
      iex> raw(schema)
      [some_field: [type: :string, required: true]]
  """
  defdelegate raw(schema), to: @implementation

  # coveralls-ignore-next-line
  defdelegate docs(schema), to: @implementation
  # coveralls-ignore-next-line
  defdelegate typespec(schema), to: @implementation
  # coveralls-ignore-next-line
  defdelegate typespec(schema, field), to: @implementation
  # coveralls-ignore-next-line
  defdelegate validate(config, schema), to: @implementation
  # coveralls-ignore-next-line
  defdelegate validate!(config, schema), to: @implementation

  @doc """
  Equivalent to `schema |> raw() |> Enum.reduce(...)`.

  ## Examples

      iex> schema = schema!(some_field: [type: :string, required: true], another_field: [type: :integer, required: false])
      iex> reduce(schema, %{}, fn key, spec, map -> Map.put(map, key, spec) end)
      %{
        some_field: [type: :string, required: true],
        another_field: [type: :integer, required: false]
      }
  """
  @spec reduce(schema, acc, reducer :: (field :: atom, spec :: keyword, acc -> acc)) :: acc
        when acc: term
  def reduce(schema, accumulator, reducer) when is_function(reducer, 3) do
    schema
    |> raw()
    |> Enum.reduce(accumulator, fn {key, spec}, acc -> reducer.(key, spec, acc) end)
  end

  @doc """
  Equivalent to `schema |> raw() |> Enum.map(...)`.

  ## Example

      iex> schema = schema!(some_field: [type: :string, required: true], another_field: [type: :integer, required: false])
      iex> map(schema, fn key, spec -> %{key: key, spec: spec} end)
      [
        %{key: :some_field, spec: [type: :string, required: true]},
        %{key: :another_field, spec: [type: :integer, required: false]},
      ]
  """
  @spec map(schema, mapper :: (field :: atom, spec :: keyword -> mapped)) :: list(mapped)
        when mapped: term
  def map(schema, mapper) when is_function(mapper, 2) do
    schema
    |> reduce([], fn key, spec, list -> [mapper.(key, spec) | list] end)
    |> Enum.reverse()
  end
end
