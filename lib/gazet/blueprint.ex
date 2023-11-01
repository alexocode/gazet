defmodule Gazet.Blueprint do
  @moduledoc false

  @type t :: t(module())
  @type t(module) :: %{:__struct__ => module, optional(atom()) => any()}

  @type result(module) :: ok(module) | error(module)
  @type ok(module) :: {:ok, t(module)}
  @type error(module) :: {:error, {:no_spec, module}} | {:error, reason :: any()}

  @callback __blueprint__(any) :: {:ok, t()} | {:error, reason :: any()}

  defguard is_blueprint(value, module) when is_struct(value, module)

  @spec build(t(mod) | mod, any) :: result(mod) when mod: module
  def build(module_or_blueprint, values \\ [])

  def build(%_{} = blueprint, []), do: {:ok, blueprint}

  def build(%module{} = blueprint, values) when is_list(values) do
    values =
      blueprint
      |> Map.from_struct()
      |> Map.to_list()
      |> Keyword.merge(values)

    build(module, values)
  end

  def build(module, %module{} = blueprint), do: {:ok, blueprint}

  def build(module, values) when is_atom(module) do
    if function_exported?(module, :__blueprint__, 1) do
      module.__blueprint__(values)
    else
      {:error, {:no_blueprint, module}}
    end
  end

  @spec build!(t(mod) | mod, any) :: t(mod) | no_return when mod: module
  def build!(module_or_blueprint, values) do
    case build(module_or_blueprint, values) do
      {:ok, blueprint} ->
        blueprint

      {:error, exception} when is_exception(exception) ->
        raise exception

      {:error, reason} ->
        raise ArgumentError,
              "unable to construct #{name(module_or_blueprint)}: " <> inspect(reason)
    end
  end

  defp name(%module{}), do: name(module)
  defp name(module) when is_atom(module), do: inspect(module)

  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)
    typespecs_for = Keyword.get(opts, :typespecs_for, [])

    quote location: :keep, bind_quoted: [schema: schema, typespecs_for: typespecs_for] do
      @behaviour Gazet.Blueprint

      Gazet.Options.map(schema, fn field, spec ->
        if typespecs_for == :all or field in typespecs_for do
          unless is_nil(spec[:doc]), do: @typedoc(spec[:doc])
          @type unquote({field, [], Elixir}) :: unquote(Gazet.Options.typespec(schema, field))
        end
      end)

      @typedoc Gazet.Options.docs(schema)
      @type blueprint :: %__MODULE__{
              unquote_splicing(
                Gazet.Options.map(schema, fn f, _ -> {f, Gazet.Options.typespec(schema, f)} end)
              )
            }
      defstruct(Gazet.Options.map(schema, &{&1, &2[:default]}))

      @impl Gazet.Blueprint
      @schema Gazet.Options.schema!(schema)
      def __blueprint__(values) do
        with {:ok, values} <- Gazet.Options.validate(values, @schema) do
          {:ok, struct(__MODULE__, values)}
        end
      end

      defoverridable __blueprint__: 1
    end
  end
end
