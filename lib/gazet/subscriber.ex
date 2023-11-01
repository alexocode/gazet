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
    init_args: [
      type: :any,
      required: false,
      doc:
        "Passed to the `init/2` callback of the subscriber. Acts as the default value for `t:context`."
    ]
  )

defmodule Gazet.Subscriber do
  # TODO: Write docs
  @moduledoc """
  Stateless subscriber.

  ## Configuration
  #{Gazet.Options.docs(schema)}
  """
  use Gazet.Blueprint,
    schema: schema

  @type t :: implementation | blueprint

  @typedoc "A module implementing this behaviour."
  @type implementation :: module

  @type opts :: [unquote(Gazet.Options.typespec(schema))]

  @type init_args :: term
  @typedoc "Used-defined data structure as returned by `init/2`. Passed as last argument to all other callbacks."
  @type context :: term

  @type result :: :ok | {:error, reason :: any}

  @callback init(blueprint :: blueprint, init_args :: init_args) ::
              {:ok, context} | {:error, reason :: any}

  @callback handle_batch(
              topic :: Gazet.topic(),
              batch ::
                nonempty_list({
                  Gazet.Message.data(),
                  Gazet.Message.metadata()
                }),
              context :: context
            ) :: result

  @spec blueprint(blueprint | opts) :: Gazet.Blueprint.result(__MODULE__)
  def blueprint(values), do: Gazet.Blueprint.build(__MODULE__, values)
  @spec blueprint!(blueprint | opts) :: blueprint | no_return
  def blueprint!(values), do: Gazet.Blueprint.build!(__MODULE__, values)

  @spec child_spec(blueprint | opts) :: Supervisor.child_spec()
  def child_spec(%__MODULE__{source: source} = subscriber) do
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
  def __blueprint__(opts) when is_list(opts) do
    # Ensure that the given opts always include the required options
    with {:ok, blueprint} <- super(opts) do
      otp_app = blueprint.otp_app || Gazet.config!(blueprint.source, :otp_app)

      [
        {:gazet, Gazet.Subscriber},
        {otp_app, Gazet.Subscriber}
      ]
      |> Gazet.Env.resolve([:adapter_opts])
      |> Keyword.merge(opts)
      |> Keyword.put(:otp_app, otp_app)
      |> super()
    end
  end

  defmacro __using__(config) do
    quote bind_quoted: [config: config] do
      @behaviour Gazet.Subscriber

      def child_spec(extra_config) do
        Gazet.Subscriber.child_spec(
          __MODULE__,
          Keyword.merge(config(), extra_config)
        )
      end

      @config Keyword.put(config, :module, __MODULE__)
      @otp_app Gazet.Subscriber.blueprint!(@config).otp_app
      def config do
        env_config = Gazet.Env.resolve(@otp_app, __MODULE__, [:adapter_opts])

        env_config
        |> Keyword.merge(@config)
        |> Gazet.Subscriber.blueprint!()
      end

      @impl Gazet.Subscriber
      def init(%Gazet.Subscriber{}, init_args), do: {:ok, init_args}

      @impl Gazet.Subscriber
      def handle_batch(topic, batch, context) do
        Enum.reduce_while(batch, :ok, fn {message, metadata}, _ ->
          with {:error, reason} <- handle_message(topic, message, metadata, context),
               {:error, reason} <- handle_error(reason, topic, message, metadata, context) do
            {:halt, {:error, reason}}
          else
            :ok -> {:cont, :ok}
          end
        end)
      end

      def handle_error(reason, _topic, _message, _metadata, _config) do
        {:error, reason}
      end

      defoverridable child_spec: 1, config: 0, init: 2, handle_batch: 3, handle_error: 5
    end
  end
end
