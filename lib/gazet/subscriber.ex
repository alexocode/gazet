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

  @callback init(blueprint, init_args) :: {:ok, context} | {:error, reason :: any}

  # @callback handle_batch(
  #             topic :: Gazet.topic(),
  #             batch ::
  #               nonempty_list({
  #                 Gazet.Message.data(),
  #                 Gazet.Message.metadata()
  #               }),
  #             context :: context
  #           ) :: result

  @callback handle_message(
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
              context :: context
            ) :: result

  @callback handle_error(
              error_reason :: any,
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
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
      def init(%Gazet.Subscriber{}, init_args), do: {:ok, init_args}

      @impl Gazet.Subscriber
      def handle_error(reason, _topic, _message, _metadata, _config) do
        {:error, reason}
      end

      defoverridable init: 2, handle_error: 5
    end
  end
end
