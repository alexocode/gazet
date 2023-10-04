if Code.ensure_loaded?(NimbleOptions) do
  defmodule Gazet.Options.NimbleOptions do
    @behaviour Gazet.Options

    @type error :: {:error, NimbleOptions.ValidationError.t()}

    @impl true
    def schema!(%NimbleOptions{} = schema), do: schema
    defdelegate schema!(schema), to: NimbleOptions, as: :new!

    @impl true
    def map(%NimbleOptions{schema: schema}, mapper) do
      map(schema, mapper)
    end

    def map(schema, mapper) when is_list(schema) and is_function(mapper, 2) do
      Enum.map(schema, fn {field, spec} -> mapper.(field, spec) end)
    end

    @impl true
    defdelegate docs(schema), to: NimbleOptions

    @impl true
    defdelegate typespec(schema), to: NimbleOptions, as: :option_typespec

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
