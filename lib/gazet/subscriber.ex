raw_schema =
  [
    otp_app: [type: :atom, required: false, doc: "Defaults to the source's `otp_app`"],
    id: [
      type: {:or, [:atom, :string]},
      required: false,
      doc: "Unique ID for this subscriber, defaults to the using module"
    ],
    source: [type: {:or, [:atom, {:struct, Gazet}]}, required: true],
    adapter_opts: [
      type: :keyword,
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

schema = Gazet.Config.schema!(raw_schema)

defmodule Gazet.Subscriber do
  # TODO: Write docs
  @moduledoc """
  ## Configuration
  #{Gazet.Config.docs(schema)}
  """

  @typedoc "A module implementing this behaviour."
  @type implementation :: module

  @typedoc raw_schema[:id][:doc]
  @type id :: atom | binary
  @typedoc raw_schema[:source][:doc]
  @type source :: Gazet.t() | Gazet.module()
  @typedoc raw_schema[:adapter_opts][:doc]
  @type adapter_opts :: keyword
  @typedoc raw_schema[:config][:doc]
  @type config :: term

  @type spec :: %__MODULE__{
          module: implementation,
          otp_app: atom,
          id: id,
          source: source,
          adapter_opts: adapter_opts,
          config: config
        }
  @enforce_keys [:module, :otp_app, :id, :source]
  defstruct [:module, :otp_app, :id, :source, {:adapter_opts, []}, :config]

  @type result :: :ok | :skip | {:error, reason :: any}

  @callback init(spec) :: {:ok, config} | {:error, reason :: any}

  @callback handle_batch(
              topic :: Gazet.topic(),
              batch ::
                nonempty_list({
                  Gazet.Message.data(),
                  Gazet.Message.metadata()
                }),
              config :: config
            ) :: result

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

  @optional_callbacks handle_message: 4, handle_error: 5

  @schema schema

  @spec child_spec(module :: implementation, opts :: [unquote(Gazet.Config.typespec(schema))]) ::
          Supervisor.child_spec()
  def child_spec(module, opts) when is_atom(module) do
    spec = spec!(module, opts)

    spec.source
    |> Gazet.spec!()
    |> Gazet.subscriber_spec(spec)
  end

  @spec spec(module :: implementation, opts :: [unquote(Gazet.Config.typespec(schema))]) ::
          {:ok, spec} | {:error, reason :: any}
  def spec(module, opts) do
    with {:ok, opts} <- Gazet.Config.validate(opts, @schema) do
      {:ok, struct(__MODULE__, [{:module, module} | opts])}
    end
  end

  @spec spec!(module :: implementation, opts :: [unquote(Gazet.Config.typespec(schema))]) ::
          spec | no_return
  def spec!(module, opts) do
    opts = Gazet.Config.validate!(opts, @schema)

    struct(__MODULE__, [{:module, module} | opts])
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
