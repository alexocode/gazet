schema =
  Gazet.Options.schema!(
    module: [
      type: :atom,
      required: true,
      doc: "A module implementing the `Gazet.Subscriber` behaviour."
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
        "A keyword list specific to the source's adapter and `c:Gazet.Adapter.subscriber_child_spec/2`. Check the adapter docs for details."
    ],
    config: [
      type: :keyword_list,
      required: false,
      doc: "Subscriber specific configuration. Passed as last argument to all callbacks."
    ]
  )

defmodule Gazet.Subscriber do
  alias Gazet.Subscriber
  # TODO: Write docs
  @moduledoc """
  ## Configuration
  #{Gazet.Options.docs(schema)}
  """
  use Gazet.Blueprint,
    schema: schema,
    typespecs_for: [:config]

  @type t :: implementation | blueprint

  @typedoc "A module implementing this behaviour."
  @type implementation :: module

  @type opts :: [unquote(Gazet.Options.typespec(schema))]
  # TODO: Allow state modification?
  @type result :: :ok | :skip | {:error, reason :: any}

  @callback init(blueprint) :: {:ok, config()} | {:error, reason :: any}

  # @callback handle_batch(
  #             topic :: Gazet.topic(),
  #             batch ::
  #               nonempty_list({
  #                 Gazet.Message.data(),
  #                 Gazet.Message.metadata()
  #               }),
  #             config :: config
  #           ) :: result

  @callback handle_message(
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
              config :: config
            ) :: result

  @callback handle_error(
              error_reason :: any,
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
              config :: config
            ) :: result

  @spec blueprint(blueprint | opts) :: Gazet.Blueprint.result(__MODULE__)
  def blueprint(values), do: Gazet.Blueprint.build(__MODULE__, values)
  @spec blueprint!(blueprint | opts) :: blueprint | no_return
  def blueprint!(values), do: Gazet.Blueprint.build!(__MODULE__, values)

  @spec child_spec(blueprint | opts) :: Supervisor.child_spec()
  def child_spec(%Subscriber{source: source} = subscriber) do
    Gazet.subscriber_child_spec(source, subscriber)
  end

  def child_spec(opts) do
    opts
    |> blueprint!()
    |> child_spec()
  end

  @spec child_spec(implementation, opts) :: Supervisor.child_spec()
  def child_spec(module, opts) when is_atom(module) do
    opts
    |> Keyword.put(:module, module)
    |> child_spec()
  end

  @impl Gazet.Blueprint
  def __blueprint__(values) do
    with {:ok, subscriber} <- super(values) do
      if is_nil(subscriber.otp_app) do
        with {:ok, otp_app} <- Gazet.config(subscriber.source, :otp_app) do
          {:ok, %{subscriber | otp_app: otp_app}}
        end
      else
        {:ok, subscriber}
      end
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Gazet.Subscriber

      @opts opts
            |> Keyword.put_new(:id, __MODULE__)
            |> Keyword.put_new_lazy(:otp_app, fn -> Gazet.config!(opts[:source], :otp_app) end)

      def child_spec(extra_config) do
        otp_app = extra_config[:otp_app] || @opts[:otp_app]

        opts =
          [
            {:gazet, Gazet.Subscriber},
            {otp_app, Gazet.Subscriber},
            {otp_app, __MODULE__}
          ]
          |> Gazet.Env.resolve()
          |> Keyword.merge(@opts)
          |> Keyword.merge(extra_config)

        Gazet.Subscriber.child_spec(__MODULE__, opts)
      end

      @impl Gazet.Subscriber
      def init(%Gazet.Subscriber{config: config}), do: {:ok, config}

      @impl Gazet.Subscriber
      def handle_error(reason, _topic, _message, _metadata, _config) do
        {:error, reason}
      end

      defoverridable init: 1, handle_error: 5
    end
  end
end
