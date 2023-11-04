defmodule Gazet.Options.Fallback do
  @moduledoc false

  @behaviour Gazet.Options

  @type error :: {:error, {:invalid_keys, expected: list(atom), found: list(atom)}}

  @impl true
  # coveralls-ignore-next-line
  def schema!(schema), do: schema

  @impl true
  # coveralls-ignore-next-line
  def raw(schema), do: schema

  @doc ~S'''
  Generates a minimalistic summary of the schema's fields.

  ## Example

      iex> schema = [some_string: [type: :string], a_number: [type: :integer]]
      iex> docs(schema)
      """
      * `:some_string` (type: :string)
      * `:a_number` (type: :integer)
      """

      iex> schema = [some_string: [type: :string, doc: "a cool string, yo!"], a_number: [type: :integer]]
      iex> docs(schema)
      """
      * `:some_string` (type: :string) - a cool string, yo!
      * `:a_number` (type: :integer)
      """
  '''
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
      "\n"
  end

  @doc """
  Generates a minimal typespec for the schema. Only supports a subset of the types that NimbleOptions does.

  ## Examples

      iex> schema = [some_string: [type: :string], a_number: [type: :integer]]
      iex> typespec(schema)
      quote do: {:a_number, integer()} | {:some_string, binary()}

      iex> schema = [
      ...>   nested_list: [type: :keyword_list],
      ...>   non_empty_nested_list: [type: :non_empty_keyword_list],
      ...>   special_map: [type: {:map, :reference, :pid}],
      ...>   weird_type: [type: {:or, [:map, :keyword_list]}]
      ...> ]
      iex> typespec(schema)
      quote do
        {:weird_type, term()} |
          {:special_map, %{reference() => pid()}} |
          {:non_empty_nested_list, nonempty_list({atom(), term()})} |
          {:nested_list, keyword()}
      end
  """
  @impl true
  def typespec(schema) do
    schema
    |> Enum.map(fn {key, _spec} -> {key, typespec(schema, key)} end)
    |> Enum.reduce(&{:|, [], [&1, &2]})
  end

  @doc """
  Generates a minimal typespec for the field in the given schema. Only supports a subset of the types that NimbleOptions does.

  See `typespec/1` for examples.
  """
  @impl true
  def typespec(schema, field) do
    schema
    |> get_in([field, :type])
    |> type_for()
  end

  @types_1to1 ~w[any atom boolean float integer non_neg_integer pos_integer pid map reference]a
  defp type_for(type) do
    case type do
      type when type in @types_1to1 ->
        {type, [], []}

      :string ->
        {:binary, [], []}

      :keyword_list ->
        {:keyword, [], []}

      :non_empty_keyword_list ->
        quote do: nonempty_list({atom(), term()})

      {:map, key_type, value_type} ->
        quote do: %{unquote(type_for(key_type)) => unquote(type_for(value_type))}

      _ ->
        {:term, [], []}
    end
  end

  @doc """
  Only checks if the given keyword list contains the required keys, nothing more.

  ## Examples

      iex> config = [string: "some string", number: 42]
      iex> validate(config, string: [type: :string, required: true], number: [type: :integer])
      {:ok, config}

      iex> config = [string: 42]
      iex> validate(config, string: [type: :string, required: true], number: [type: :integer])
      {:ok, config}

      iex> config = [number: 42]
      iex> validate(config, string: [type: :string, required: true], number: [type: :integer])
      {:error, {:invalid_keys, expected: [:string], found: [:number]}}
  """
  @impl true
  def validate(config, schema) do
    config_keys = Keyword.keys(config)
    schema_keys = for {key, spec} <- schema, spec[:required], do: key

    if Enum.all?(schema_keys, &Enum.member?(config_keys, &1)) do
      {:ok, config}
    else
      {:error, {:invalid_keys, expected: schema_keys, found: config_keys}}
    end
  end

  @doc """
  Only checks if the given keyword list contains the required keys, nothing more.

  Raises an `ArgumentError` if not.

  ## Examples

      iex> config = [string: "some string", number: 42]
      iex> validate!(config, string: [type: :string, required: true], number: [type: :integer])
      config

      iex> config = [string: 42]
      iex> validate!(config, string: [type: :string, required: true], number: [type: :integer])
      config

      iex> config = [number: 42]
      iex> validate!(config, string: [type: :string, required: true], number: [type: :integer])
      ** (ArgumentError) config doesn't match schema: {:invalid_keys, [expected: [:string], found: [:number]]}
  """
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
