schema =
  Blueprint.Options.schema!(
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
  #{Blueprint.Options.docs(schema)}
  """
  use Blueprint, schema: schema

  alias Gazet.Adapter
  alias Gazet.Message

  @typedoc "A module implementing `Gazet` or a `Gazet` blueprint."
  @type t :: implementation | blueprint

  @typedoc "A module implementing this behaviour."
  @type implementation :: module

  @type opts :: [unquote(Blueprint.Options.typespec(schema))]

  @type adapter :: Adapter.t() | Adapter.blueprint()
  @type name :: atom
  @type topic :: atom | binary

  @callback config() :: blueprint | opts

  # TODO: Probably add something like a Config server under a supervisor
  @doc """
  Returns a `t:Supervisor.child_spec` for starting this `Gazet` in a supervision tree.

  The specifics of the child spec depend on the gazet's `t:adapter`.
  """
  @spec child_spec(t) :: Supervisor.child_spec()
  def child_spec(gazet) do
    gazet
    |> adapter()
    |> Adapter.child_spec()
  end

  @doc """
  Publishes a message with optional metadata to the given `Gazet` - or rather
  specifically to its `topic`.

  The specifics of how the message gets published depend on the gazet's `t:adapter`.
  """
  @spec publish(t, message :: Message.data(), metadata :: Message.metadata()) ::
          :ok | {:error, reason :: any}
  def publish(gazet, message, metadata \\ %{}) do
    gazet
    |> adapter()
    |> Adapter.publish(%Message{data: message, metadata: metadata})
  end

  @doc """
  Returns a `t:Supervisor.child_spec` for starting a `Gazet.Subscriber` that
  receives events from the given `Gazet`.

  The specifics of the child spec depend on the gazet's `t:adapter`.
  """
  @spec subscriber_child_spec(t, subscriber :: Gazet.Subscriber.blueprint()) ::
          Supervisor.child_spec()
  def subscriber_child_spec(gazet, %Gazet.Subscriber{} = subscriber) do
    gazet
    |> adapter()
    |> Adapter.subscriber_child_spec(subscriber)
  end

  @doc """
  Returns the `t:Gazet.Adapter.blueprint` for the given `Gazet`.

  ## Examples

      iex> gazet = %Gazet{otp_app: :gazet, adapter: Gazet.Adapter.Local, name: MyGazet, topic: "my_topic"}
      iex> adapter(gazet)
      %Gazet.Adapter{
        module: Gazet.Adapter.Local,
        name: MyGazet.Adapter,
        topic: "my_topic",
        config: []
      }

      iex> gazet = %Gazet{otp_app: :gazet, adapter: {Gazet.Adapter.Local, my: "config"}, name: MyGazet, topic: "my_topic"}
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
  @spec adapter(t) :: Adapter.blueprint()
  def adapter(%Gazet{adapter: %Gazet.Adapter{} = adapter}), do: adapter

  def adapter(%Gazet{adapter: adapter, name: name, topic: topic}) do
    Adapter.blueprint!(adapter,
      name: Module.concat(name, "Adapter"),
      topic: topic
    )
  end

  def adapter(gazet) do
    gazet
    |> blueprint!()
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
      {:error, {:no_config_function, :not_a_gazet}}

      iex> config("not a gazet", :topic)
      {:error, {:unexpected_value, "not a gazet"}}
  """
  Blueprint.Options.map(schema, fn field, _spec ->
    type = Blueprint.Options.typespec(schema, field)

    @spec config(t | opts, unquote(field)) ::
            {:ok, unquote(type)} | Blueprint.error(__MODULE__)
    def config(gazet, unquote(field)) do
      with {:ok, %{unquote(field) => value}} <- blueprint(gazet) do
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
      ** (ArgumentError) unable to construct Gazet: {:no_config_function, :not_a_gazet}

      iex> config!("not a gazet", :topic)
      ** (ArgumentError) unable to construct Gazet: {:unexpected_value, "not a gazet"}
  """
  Blueprint.Options.map(schema, fn field, _spec ->
    type = Blueprint.Options.typespec(schema, field)

    @spec config!(t | opts, unquote(field)) :: unquote(type) | no_return
    def config!(gazet, unquote(field)), do: Map.fetch!(blueprint!(gazet), unquote(field))
  end)

  @doc """
  Transforms a module-based Gazet or a list of options into a `t:Gazet.Blueprint`.

  ## Examples

      iex> blueprint(otp_app: :my_app, adapter: Gazet.Adapter.Local, name: MyCoolGazet, topic: "great topic")
      {:ok, %Gazet{otp_app: :my_app, adapter: Gazet.Adapter.Local, name: MyCoolGazet, topic: "great topic"}}

      iex> defmodule MyCoolModuleGazet do
      ...>   use Gazet,
      ...>     otp_app: :my_cool_app,
      ...>     adapter: {Gazet.Adapter.Local, my: "config"},
      ...>     topic: "the_best_topic"
      ...> end
      iex> blueprint(MyCoolModuleGazet)
      {:ok, %Gazet{otp_app: :my_cool_app, adapter: {Gazet.Adapter.Local, my: "config"}, name: MyCoolModuleGazet, topic: "the_best_topic"}}

      iex> blueprint(:wat)
      {:error, {:no_config_function, :wat}}

      iex> blueprint("wat")
      {:error, {:unexpected_value, "wat"}}
  """
  @spec blueprint(t | opts) :: Blueprint.result(__MODULE__)
  def blueprint(value), do: Blueprint.build(__MODULE__, value)

  @doc """
  Like `blueprint/1` but raises any errors.

  ## Examples

      iex> blueprint!(otp_app: :my_app, adapter: Gazet.Adapter.Local, name: MyCoolGazet, topic: "great topic")
      %Gazet{otp_app: :my_app, adapter: Gazet.Adapter.Local, name: MyCoolGazet, topic: "great topic"}

      iex> defmodule MyCoolModuleGazet2 do
      ...>   use Gazet,
      ...>     otp_app: :my_cool_app,
      ...>     adapter: {Gazet.Adapter.Local, my: "config"},
      ...>     topic: "the_best_topic"
      ...> end
      iex> blueprint!(MyCoolModuleGazet2)
      %Gazet{otp_app: :my_cool_app, adapter: {Gazet.Adapter.Local, my: "config"}, name: MyCoolModuleGazet2, topic: "the_best_topic"}

      iex> blueprint!(:wat)
      ** (ArgumentError) unable to construct Gazet: {:no_config_function, :wat}

      iex> blueprint!("wat")
      ** (ArgumentError) unable to construct Gazet: {:unexpected_value, "wat"}
  """
  @spec blueprint!(t | opts) :: blueprint | no_return
  def blueprint!(value), do: Blueprint.build!(__MODULE__, value)

  @impl Blueprint
  def __blueprint__(%__MODULE__{} = blueprint), do: {:ok, blueprint}

  def __blueprint__(module) when is_atom(module) do
    if function_exported?(module, :config, 0) do
      __blueprint__(module.config())
    else
      {:error, {:no_config_function, module}}
    end
  end

  def __blueprint__(opts) when is_list(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    [
      {:gazet, Gazet},
      {otp_app, Gazet}
    ]
    |> Gazet.Env.resolve([:adapter])
    |> Keyword.merge(opts)
    |> super()
  end

  def __blueprint__(wat), do: {:error, {:unexpected_value, wat}}

  defmacro __using__(config) do
    quote bind_quoted: [config: config] do
      @behaviour Gazet

      # TODO: Print a warning when passing additional information
      def child_spec([]) do
        Gazet.child_spec(__MODULE__)
      end

      @config Keyword.put_new(config, :name, __MODULE__)
      @otp_app Keyword.fetch!(config, :otp_app)
      @impl Gazet
      def config do
        env_config = Gazet.Env.resolve({@otp_app, __MODULE__}, [:adapter])

        env_config
        |> Keyword.merge(@config)
        |> Gazet.blueprint!()
      end
    end
  end
end
