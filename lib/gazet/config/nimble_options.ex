if Code.loaded?(NimbleOptions) do
  defmodule Gazet.Config.NimbleOptions do
    @behaviour Gazet.Config

    @impl true
    defdelegate schema!(schema), to: NimbleOptions, as: :new!

    @impl true
    defdelegate docs(schema), to: NimbleOptions

    @impl true
    defdelegate typespec(schema), to: NimbleOptions, as: :option_typespec

    @impl true
    defdelegate validate(config, schema), to: NimbleOptions

    @impl true
    defdelegate validate!(config, schema), to: NimbleOptions
  end
end
