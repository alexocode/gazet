schema =
  Gazet.Options.schema!(
    otp_app: [
      type: :atom,
      required: true
    ],
    adapter: [
      type: {:or, [:atom, :mod_arg]},
      required: true,
      doc:
        "The adapter used for publishing and subscribing; either a module or a {module, config} tuple."
    ],
    name: [type: :atom, required: true, doc: "The name of the Gazet (used for Supervision)."],
    topic: [
      type: {:or, [:atom, :string]},
      required: true,
      doc: "The topic under which messages will be published."
    ]
  )

defmodule Gazet do
  @moduledoc """

  defmodule Backend.Content.Events do
    use Gazet,
      otp_app: :sevenmind,
      adapter: {Backend.External.GooglePubSubAdapter, ...},
      topic: "content"
  end

  Backend.Content.Events.publish(%{some: "message"}, %{some: "metadata"})

  defmodule MyContentEventHandler do
    use Gazet.Subscriber,
      id: "content-subscriber-for-some-subdomain",
      source: Backend.Content.Events,
      additional_config: "..."

    def init(config) do
      {:ok, Keyword.put(config, :something, "blalbla")}
    end

    def handle_event(_topic, %{some: message}, metadata, _subscriber_config) do
    end
  end

  ## Configuration
  #{Gazet.Options.docs(schema)}
  """
  use Gazet.Spec, schema: schema

  alias Gazet.Adapter
  alias Gazet.Message

  @typedoc "A module implementing `Gazet` or a `Gazet` spec."
  @type t :: implementation | spec

  @typedoc "A module implementing this behaviour."
  @type implementation :: module

  @type opts :: [unquote(Gazet.Options.typespec(schema))]

  @type adapter :: Adapter.t() | Adapter.spec()
  @type name :: atom
  @type topic :: atom | binary

  @callback __gazet__() :: spec

  # TODO: Probably add something like a Config server under a supervisor
  @spec child_spec(t) :: Supervisor.child_spec()
  def child_spec(gazet) do
    gazet
    |> adapter()
    |> Adapter.child_spec()
  end

  @spec publish(t, message :: Message.data(), metadata :: Message.metadata()) ::
          :ok | {:error, reason :: any}
  def publish(gazet, message, metadata) do
    gazet
    |> adapter()
    |> Adapter.publish(%Message{data: message, metadata: metadata})
  end

  @spec subscriber_spec(t, subscriber :: Gazet.Subscriber.spec()) :: Supervisor.child_spec()
  def subscriber_spec(gazet, %Gazet.Subscriber{} = subscriber) do
    gazet
    |> adapter()
    |> Adapter.subscriber_spec(subscriber)
  end

  @doc """
  Returns the `t:Gazet.Adapter.spec` for the given `Gazet`.

  ## Examples

      iex> gazet = %Gazet{adapter: Gazet.Adapter.Local, name: MyGazet, topic: "my_topic"}
      iex> adapter(gazet)
      %Gazet.Adapter{
        module: Gazet.Adapter.Local,
        name: MyGazet.Adapter,
        topic: "my_topic",
        config: []
      }

      iex> gazet = %Gazet{adapter: {Gazet.Adapter.Local, my: "config"}, name: MyGazet, topic: "my_topic"}
      iex> adapter(gazet)
      %Gazet.Adapter{
        module: Gazet.Adapter.Local,
        name: MyGazet.Adapter,
        topic: "my_topic",
        config: [my: "config"]
      }

      iex> defmodule MyGazet do
      ...>   use Gazet,
      ...>     otp_app: :my_app,
      ...>     adapter: {Gazet.Adapter.Local, my: "config"},
      ...>     topic: "my_topic"
      ...> end
      iex> adapter(MyGazet)
      %Gazet.Adapter{
        module: Gazet.Adapter.Local,
        name: MyGazet.Adapter,
        topic: "my_topic",
        config: [my: "config"]
      }
  """
  @spec adapter(t) :: Adapter.spec()
  def adapter(%Gazet{adapter: %Gazet.Adapter{} = adapter}), do: adapter

  def adapter(%Gazet{adapter: adapter, name: name, topic: topic}) do
    Adapter.spec!(adapter,
      name: Module.concat(name, "Adapter"),
      topic: topic
    )
  end

  def adapter(gazet) do
    gazet
    |> spec!()
    |> adapter()
  end

  @doc """
  Fetches the config value for the given key.

  ## Examples

      iex> gazet = %Gazet{otp_app: :my_app, adapter: Gazet.Adapter.Local, name: MyGazet, topic: "my_topic"}
      iex> config(gazet, :otp_app)
      {:ok, :my_app}
      iex> config(gazet, :adapter)
      {:ok, Gazet.Adapter.Local}
      iex> config(gazet, :name)
      {:ok, MyGazet}
      iex> config(gazet, :topic)
      {:ok, "my_topic"}

      iex> defmodule ModuleGazet do
      ...>   use Gazet,
      ...>     otp_app: :another_app,
      ...>     adapter: {Gazet.Adapter.Local, my: "config"},
      ...>     topic: "the_best_topic"
      ...> end
      iex> config(ModuleGazet, :otp_app)
      {:ok, :another_app}
      iex> config(ModuleGazet, :adapter)
      {:ok, {Gazet.Adapter.Local, my: "config"}}
      iex> config(ModuleGazet, :name)
      {:ok, ModuleGazet}
      iex> config(ModuleGazet, :topic)
      {:ok, "the_best_topic"}

      iex> config(:not_a_gazet, :topic)
      {:error, {:missing_impl, Gazet, :not_a_gazet}}

      iex> config("not a gazet", :topic)
      {:error, {:unexpected_value, "not a gazet"}}
  """
  Gazet.Options.map(schema, fn field, _spec ->
    type = Gazet.Options.typespec(schema, field)

    @spec config(t | opts, unquote(field)) :: {:ok, unquote(type)} | Gazet.Spec.error(__MODULE__)
    def config(gazet, unquote(field)) do
      with {:ok, %{unquote(field) => value}} <- spec(gazet) do
        {:ok, value}
      end
    end
  end)

  @doc """
  Like `config/2` but raises any errors.

  ## Examples

      iex> gazet = %Gazet{otp_app: :my_app, adapter: Gazet.Adapter.Local, name: MyGazet, topic: "my_topic"}
      iex> config!(gazet, :otp_app)
      :my_app
      iex> config!(gazet, :adapter)
      Gazet.Adapter.Local
      iex> config!(gazet, :name)
      MyGazet
      iex> config!(gazet, :topic)
      "my_topic"

      iex> defmodule AnotherModuleGazet do
      ...>   use Gazet,
      ...>     otp_app: :another_app,
      ...>     adapter: {Gazet.Adapter.Local, my: "config"},
      ...>     topic: "the_best_topic"
      ...> end
      iex> config!(AnotherModuleGazet, :otp_app)
      :another_app
      iex> config!(AnotherModuleGazet, :adapter)
      {Gazet.Adapter.Local, my: "config"}
      iex> config!(AnotherModuleGazet, :name)
      AnotherModuleGazet
      iex> config!(AnotherModuleGazet, :topic)
      "the_best_topic"

      iex> config!(:not_a_gazet, :topic)
      ** (ArgumentError) unable to construct Gazet: {:missing_impl, Gazet, :not_a_gazet}

      iex> config!("not a gazet", :topic)
      ** (ArgumentError) unable to construct Gazet: {:unexpected_value, "not a gazet"}
  """
  Gazet.Options.map(schema, fn field, _spec ->
    type = Gazet.Options.typespec(schema, field)

    @spec config!(t | opts, unquote(field)) :: unquote(type) | no_return
    def config!(gazet, unquote(field)), do: Map.fetch!(spec!(gazet), unquote(field))
  end)

  @spec spec(t | opts) :: Gazet.Spec.result(__MODULE__)
  def spec(to_spec), do: Gazet.Spec.build(__MODULE__, to_spec)
  @spec spec!(t | opts) :: spec | no_return
  def spec!(to_spec), do: Gazet.Spec.build!(__MODULE__, to_spec)

  @impl Gazet.Spec
  def __spec__(module) when is_atom(module) do
    if function_exported?(module, :__gazet__, 0) do
      module.__gazet__()
    else
      {:error, {:missing_impl, Gazet, module}}
    end
  end

  def __spec__(opts) when is_list(opts), do: super(opts)
  def __spec__(wat), do: {:error, {:unexpected_value, wat}}

  defmacro __using__(config) do
    quote bind_quoted: [config: config] do
      @behaviour Gazet

      @config config
      @otp_app Keyword.fetch!(config, :otp_app)

      # TODO: Print a warning when passing additional information
      def child_spec([]) do
        Gazet.child_spec(__MODULE__)
      end

      @impl Gazet
      def __gazet__ do
        env_config = Application.get_env(@otp_app, __MODULE__, [])

        @config
        |> Keyword.merge(env_config)
        |> Keyword.put_new(:name, __MODULE__)
        |> Gazet.__spec__()
      end
    end
  end
end
