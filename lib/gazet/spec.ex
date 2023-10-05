defmodule Gazet.Spec do
  @moduledoc false

  @type t :: t(module())
  @type t(module) :: %{:__struct__ => module, optional(atom()) => any()}

  @type result(module) :: ok(module) | error(module)
  @type ok(module) :: {:ok, t(module)}
  @type error(module) :: {:error, {:no_spec, module}} | {:error, reason :: any()}

  @callback __spec__(any) :: {:ok, t()} | {:error, reason :: any()}

  defguard is_spec(value, module) when is_struct(value, module)

  @spec build(t(module) | module, any) :: result(module) when module: module
  def build(module_or_spec, values \\ [])

  def build(%_{} = spec, []), do: {:ok, spec}

  def build(%module{} = spec, values) when is_list(values) do
    values =
      spec
      |> Map.from_struct()
      |> Map.to_list()
      |> Keyword.merge(values)

    build(module, values)
  end

  def build(module, %module{} = spec), do: {:ok, spec}

  def build(module, values) when is_atom(module) do
    if function_exported?(module, :__spec__, 1) do
      module.__spec__(values)
    else
      {:error, {:no_spec, module}}
    end
  end

  @spec build!(t(module) | module, any) :: t(module) | no_return when module: module
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

      Gazet.Options.map(schema, fn field, spec ->
        if typespecs_for == :all or field in typespecs_for do
          unless is_nil(spec[:doc]), do: @typedoc(spec[:doc])
          @type unquote({field, [], Elixir}) :: unquote(Gazet.Options.typespec(schema, field))
        end
      end)

      @typedoc Gazet.Options.docs(schema)
      @type spec :: %__MODULE__{
              unquote_splicing(
                Gazet.Options.map(schema, fn f, _ -> {f, Gazet.Options.typespec(schema, f)} end)
              )
            }
      defstruct(Gazet.Options.map(schema, &{&1, &2[:default]}))

      @impl Gazet.Spec
      @schema Gazet.Options.schema!(schema)
      def __spec__(values) do
        with {:ok, values} <- Gazet.Options.validate(values, @schema) do
          {:ok, struct(__MODULE__, values)}
        end
      end

      defoverridable __spec__: 1
    end
  end
end
