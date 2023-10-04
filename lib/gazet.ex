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

  @spec spec(t | opts) :: Gazet.Spec.result(__MODULE__)
  def spec(to_spec), do: Gazet.Spec.build(__MODULE__, to_spec)
  @spec spec!(t | opts) :: spec | no_return
  def spec!(to_spec), do: Gazet.Spec.build!(__MODULE__, to_spec)

  @impl Gazet.Spec
  def __spec__(module) when is_atom(module), do: module.__gazet__()
  def __spec__(opts), do: super(opts)

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
