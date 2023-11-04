if Code.ensure_loaded?(NimbleOptions) do
  defmodule Gazet.Options.NimbleOptions do
    @behaviour Gazet.Options

    @type error :: {:error, NimbleOptions.ValidationError.t()}

    @doc """
    Thin wrapper around `NimbleOptions.new!/1`.

    ## Examples

        iex> raw_schema = [some_key: [type: :string]]
        iex> schema!(raw_schema)
        NimbleOptions.new!(raw_schema)

        iex> raw_schema = [some_key: [type: :string]]
        iex> schema = schema!(raw_schema)
        iex> schema!(schema)
        schema
    """
    @impl true
    def schema!(%NimbleOptions{} = schema), do: schema
    defdelegate schema!(schema), to: NimbleOptions, as: :new!

    @doc """
    Unwraps a schema previously passed to `schema!/1`.

    ## Examples

        iex> raw_schema = [some_key: [type: :string, required: true]]
        iex> schema = schema!(raw_schema)
        iex> raw(schema)
        raw_schema

        iex> raw_schema = [some_key: [type: :string, required: true]]
        iex> raw(raw_schema)
        raw_schema
    """
    @impl true
    def raw(%NimbleOptions{schema: schema}), do: schema
    def raw(schema), do: schema

    @impl true
    defdelegate docs(schema), to: NimbleOptions

    @impl true
    defdelegate typespec(schema), to: NimbleOptions, as: :option_typespec

    @doc """
    Generates the AST for the typespec of a single field.

    ## Examples

        iex> schema = schema!(my_string: [type: :string], my_number: [type: :integer], my_map: [type: :map])
        iex> typespec(schema, :my_string)
        quote do: binary()
        iex> typespec(schema, :my_number)
        quote do: integer()
        iex> typespec(schema, :my_map)
        quote do: map()
    """
    @impl true
    def typespec(%NimbleOptions{schema: schema}, field) do
      typespec(schema, field)
    end

    def typespec(schema, field) when is_list(schema) do
      spec = Keyword.fetch!(schema, field)

      {_field, type} = NimbleOptions.option_typespec([{field, spec}])

      type
    end

    @impl true
    defdelegate validate(config, schema), to: NimbleOptions

    @impl true
    defdelegate validate!(config, schema), to: NimbleOptions
  end
end
