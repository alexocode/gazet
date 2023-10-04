schema =
  [
    handler: [
      type: :atom,
      required: true,
      doc: "The actual subscriber module that handles messages."
    ],
    otp_app: [type: :atom, required: false, doc: "Defaults to the source's `otp_app`"],
    id: [
      type: {:or, [:atom, :string]},
      required: false,
      doc: "Unique ID for this subscriber, defaults to the using module"
    ],
    source: [type: {:or, [:atom, {:struct, Gazet}]}, required: true],
    adapter_opts: [
      type: :keyword_list,
      default: [],
      doc:
        "A keyword list specific to the source's adapter and `c:Gazet.Adapter.subscriber_spec/2`. Check the adapter docs for details."
    ],
    config: [
      type: :any,
      required: false,
      doc:
        "Subscriber specific configuration, can be anything. Passed as last argument to all callbacks."
    ]
  ]

defmodule Gazet.Subscriber do
  # TODO: Write docs
  @moduledoc """
  ## Configuration
  #{Gazet.Config.docs(schema)}
  """
  use Gazet.Spec,
    schema: schema,
    typespecs_for: [:config]

  @type t :: implementation | spec

  @typedoc "A module implementing this behaviour."
  @type implementation :: module

  @type opts :: [unquote(Gazet.Config.typespec(schema))]
  @type result :: :ok | :skip | {:error, reason :: any}

  @callback init(spec) :: {:ok, config()} | {:error, reason :: any}

  @callback handle_batch(
              topic :: Gazet.topic(),
              batch ::
                nonempty_list({
                  Gazet.Message.data(),
                  Gazet.Message.metadata()
                }),
              config :: config()
            ) :: result

  @callback handle_message(
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
              config :: config()
            ) :: result

  @callback handle_error(
              error_reason :: any,
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
              config :: config()
            ) :: result

  @optional_callbacks handle_message: 4, handle_error: 5

  @spec spec(spec | opts) :: Gazet.Spec.result(__MODULE__)
  def spec(values), do: Gazet.Spec.build(__MODULE__, values)
  @spec spec!(spec | opts) :: spec | no_return
  def spec!(values), do: Gazet.Spec.build!(__MODULE__, values)

  @spec child_spec(opts) :: Supervisor.child_spec()
  def child_spec(opts) do
    spec = spec!(opts)

    spec.source
    |> Gazet.spec!()
    |> Gazet.subscriber_spec(spec)
  end

  @impl Gazet.Spec
  def __spec__(values) do
    with {:ok, subscriber_spec} <- super(values),
         {:ok, gazet_spec} <- Gazet.spec(subscriber_spec.source) do
      {:ok, %{subscriber_spec | otp_app: subscriber_spec.otp_app || gazet_spec.otp_app}}
    end
  end

  defmacro __using__(config) do
    quote bind_quoted: [config: config] do
      @behaviour Gazet.Subscriber

      @config config
              |> Keyword.put_new(:id, __MODULE__)
              |> Keyword.put_new_lazy(:otp_app, fn -> config[:source].__gazet__()[:otp_app] end)

      def child_spec(extra_config) do
        otp_app = extra_config[:otp_app] || @config[:otp_app]

        config =
          @config
          |> Keyword.merge(Application.get_env(otp_app, __MODULE__, []))
          |> Keyword.merge(extra_config)

        Gazet.Subscriber.child_spec(__MODULE__, config)
      end

      @impl Gazet.Subscriber
      def init(%Gazet.Subscriber{extra: extra}), do: {:ok, extra}

      defoverridable init: 1
    end
  end
end
