schema =
  Gazet.Config.schema!(
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
    name: [type: :atom, required: true, doc: "The name of the Gazet (user for Supervision)."],
    topic: [
      type: {:or, [:atom, :string]},
      required: true,
      doc: "The topic under which messages will be published."
    ]
  )

defmodule Gazet do
  @moduledoc """
  ## Configuration
  #{Gazet.Config.docs(schema)}
  """
  use Gazet.Spec, schema: schema

  alias Gazet.Adapter
  alias Gazet.Config
  alias Gazet.Message

  @typedoc "A module implementing `Gazet` or a `Gazet` spec."
  @type t :: implementation | spec

  @typedoc "A module implementing this behaviour."
  @type implementation :: module

  @type opts :: [unquote(Gazet.Config.typespec(schema))]

  @type adapter :: Adapter.t() | Adapter.spec()
  @type name :: atom
  @type topic :: atom | binary

  @spec spec(spec | opts) :: Gazet.Spec.result(__MODULE__)
  def spec(values), do: Gazet.Spec.build(__MODULE__, values)
  @spec spec!(spec | opts) :: spec | no_return
  def spec!(values), do: Gazet.Spec.build!(__MODULE__, values)

  @spec publish(t, message :: Message.data(), metadata :: Message.metadata()) ::
          :ok | {:error, reason :: any}
  def publish(%__MODULE__{} = gazet, message, metadata) do
    gazet
    |> adapter()
    |> Adapter.publish(%Message{data: message, metadata: metadata})
  end

  @spec subscriber_spec(t, subscriber :: Gazet.Subscriber.spec()) :: Supervisor.child_spec()
  def subscriber_spec(%__MODULE__{} = gazet, %Gazet.Subscriber{} = subscriber) do
    gazet
    |> adapter()
    |> Adapter.subscriber_spec(subscriber)
  end

  @spec adapter(t) :: Adapter.spec()
  def adapter(%__MODULE__{adapter: adapter, name: name, topic: topic}) do
    Adapter.spec(adapter,
      name: Module.concat(name, "Adapter"),
      topic: topic
    )
  end

  defmacro __using__(config) do
    otp_app = Keyword.fetch!(config, :otp_app)

    quote bind_quoted: [otp_app: otp_app, config: config] do
      @behaviour Gazet

      @impl Gazet
      def __gazet__ do
        config = unquote(config)
        env_config = Application.get_env(unquote(otp_app), __MODULE__, [])

        config
        |> Keyword.merge(env_config)
        |> Gazet.spec!()
      end
    end
  end
end
