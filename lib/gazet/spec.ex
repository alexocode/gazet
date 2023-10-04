defmodule Gazet.Spec do
  @moduledoc false

  @type t :: t(module())
  @type t(module) :: %{:__struct__ => module, optional(atom()) => any()}

  @type result(module) ::
          {:ok, t(module)}
          | {:error, {:no_spec, module}}
          | {:error, reason :: any()}

  @callback __spec__(keyword) :: {:ok, t()} | {:error, reason :: any()}

  defguard is_spec(value, module) when is_struct(value, module)

  @spec build(t(module) | module, keyword) :: result(module) when module: module
  def build(module_or_spec, values \\ [])

  def build(%_{} = spec, []), do: {:ok, spec}

  def build(%module{} = spec, values) do
    values =
      spec
      |> Map.from_struct()
      |> Map.to_list()
      |> Keyword.merge(values)

    build(module, values)
  end

  def build(module, values) when is_atom(module) do
    if function_exported?(module, :__spec__, 1) do
      module.__spec__(values)
    else
      {:error, {:no_spec, module}}
    end
  end

  @spec build!(t(module) | module, keyword) :: t(module) | no_return when module: module
  def build!(module_or_spec, values) do
    case build(module_or_spec, values) do
      {:ok, spec} ->
        spec

      {:error, exception} when is_exception(exception) ->
        raise exception

      {:error, reason} ->
        raise ArgumentError, "unable to construct spec: " <> inspect(reason)
    end
  end

  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)
    typespecs_for = Keyword.get(opts, :typespecs_for, [])

    quote location: :keep, bind_quoted: [schema: schema, typespecs_for: typespecs_for] do
      @behaviour Gazet.Spec

      Gazet.Config.map(schema, fn field, spec ->
        if typespecs_for == :all or field in typespecs_for do
          unless is_nil(spec[:doc]), do: @typedoc(spec[:doc])
          @type unquote({field, [], Elixir}) :: unquote(Gazet.Config.typespec(schema, field))
        end
      end)

      @typedoc Gazet.Config.docs(schema)
      @type spec :: %__MODULE__{
              unquote_splicing(
                Gazet.Config.map(schema, fn f, _ -> {f, Gazet.Config.typespec(schema, f)} end)
              )
            }
      defstruct(Gazet.Config.map(schema, &{&1, &2[:default]}))

      @impl Gazet.Spec
      @schema Gazet.Config.schema!(schema)
      def __spec__(values) do
        with {:ok, values} <- Gazet.Config.validate(values, @schema) do
          {:ok, struct(__MODULE__, values)}
        end
      end

      defoverridable __spec__: 1
    end
  end
end
