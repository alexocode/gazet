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

  @callback config() :: blueprint | opts

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

  @spec blueprint(t | opts) :: Gazet.Blueprint.result(__MODULE__)
  def blueprint(module_or_opts), do: Gazet.Blueprint.build(__MODULE__, module_or_opts)
  @spec blueprint!(t | opts) :: blueprint | no_return
  def blueprint!(module_or_opts), do: Gazet.Blueprint.build!(__MODULE__, module_or_opts)

  @spec child_spec(t | opts) :: Supervisor.child_spec()
  def child_spec(%__MODULE__{source: source} = subscriber) do
    Gazet.subscriber_child_spec(source, subscriber)
  end

  def child_spec(module_or_opts) do
    module_or_opts
    |> blueprint!()
    |> child_spec()
  end

  @spec child_spec(implementation, opts) :: Supervisor.child_spec()
  def child_spec(module, overrides) when is_atom(module) do
    base_opts =
      case module.config() do
        %__MODULE__{} = blueprint ->
          blueprint
          |> Map.from_struct()
          |> Map.to_list()

        opts when is_list(opts) ->
          opts
      end

    base_opts
    |> Keyword.merge(Keyword.take(overrides, [:id, :otp_app, :source, :adapter_opts, :init_args]))
    |> child_spec()
  end

  @impl Gazet.Blueprint
  def __blueprint__(module) when is_atom(module) do
    if function_exported?(module, :config, 0) do
      case module.config() do
        %__MODULE__{} = blueprint ->
          {:ok, %__MODULE__{blueprint | module: module}}

        opts when is_list(opts) ->
          opts
          |> Keyword.put(:module, module)
          |> __blueprint__()
      end
    else
      {:error, {:no_config_function, module}}
    end
  end

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

      def child_spec(overrides) do
        Gazet.Subscriber.child_spec(__MODULE__, overrides)
      end

      @config Keyword.put(config, :module, __MODULE__)
      @otp_app Gazet.Subscriber.blueprint!(@config).otp_app
      @impl Gazet.Subscriber
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
