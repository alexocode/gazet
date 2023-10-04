schema =
  Gazet.Config.schema!(
    otp_app: [type: :atom, required: false, doc: "Defaults to the source's `otp_app`"],
    id: [
      type: {:or, [:atom, :string]},
      required: false,
      doc: "Unique ID for this subscriber, defaults to the using module"
    ],
    source: [type: {:or, [:atom, {:struct, Gazet}]}, required: true]
  )

defmodule Gazet.Subscriber do
  # TODO: Write docs
  @moduledoc """
  ## Configuration
  #{Gazet.Config.docs(schema)}
  """

  @typedoc "A module implementing this behaviour."
  @type t :: module
  @type spec :: {t, config}

  @typedoc "A keyword list of configuration values, some shared, some specific for each subscriber."
  @type config :: [shared_config | {atom, term}]
  @type shared_config ::
          {:id, id}
          | {:source, source}

  @type id :: atom | binary
  @type source :: Gazet.t() | Gazet.module()

  @callback config() :: config

  @callback init(config) :: {:ok, config} | {:error, reason :: any}

  @callback handle_event(
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
              config
            ) :: :ok | :skip | {:error, reason :: any}

  @callback handle_error(
              error_reason :: any,
              topic :: Gazet.topic(),
              message :: Gazet.Message.data(),
              metadata :: Gazet.Message.metadata(),
              config
            ) :: :ok | :skip | {:error, reason :: any}

  @optional_callbacks init: 1, handle_error: 5

  defmacro __using__(config) do
    quote bind_quoted: [config: config] do
      @behaviour Gazet.Subscriber

      @config config
              |> Keyword.put_new(:id, __MODULE__)
              |> Keyword.put_new_lazy(:otp_app, fn -> config[:source].__gazet__()[:otp_app] end)

      @impl Gazet.Subscriber
      def config do
        Keyword.merge(
          @config,
          Application.get_env(@config[:otp_app], __MODULE__, [])
        )
      end
    end
  end
end
