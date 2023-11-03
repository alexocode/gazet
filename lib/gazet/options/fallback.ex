defmodule Gazet.Options.Fallback do
  @moduledoc false

  @behaviour Gazet.Options

  @type error :: {:error, {:invalid_keys, expected: list(atom), found: list(atom)}}

  @impl true
  def schema!(schema), do: schema

  @impl true
  def raw(schema), do: schema

  @impl true
  def docs(schema) do
    Enum.map_join(schema, "\n", fn {key, spec} ->
      "* `#{inspect(key)}` (type: #{inspect(spec[:type])})" <>
        if spec[:doc] do
          " - " <> spec[:doc]
        else
          ""
        end
    end) <>
      "\n\n"
  end

  @impl true
  def typespec(schema) do
    schema
    |> Enum.map(fn {key, _spec} -> {key, {:term, [], Elixir}} end)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end

  @impl true
  def typespec(_schema, _field), do: {:term, [], Elixir}

  @impl true
  def validate(config, schema) do
    config_keys =
      config
      |> Keyword.keys()
      |> Enum.sort()

    schema_keys =
      schema
      |> Keyword.keys()
      |> Enum.sort()

    if config_keys == schema_keys do
      {:ok, config}
    else
      {:error, {:invalid_keys, expected: schema_keys, found: config_keys}}
    end
  end

  @impl true
  def validate!(config, schema) do
    case validate(config, schema) do
      {:ok, config} ->
        config

      {:error, reason} ->
        raise ArgumentError, "config doesn't match schema: " <> inspect(reason)
    end
  end
end
