defmodule Gazet.Adapter do
  @typedoc "A module implementing this behaviour."
  @type t :: module
  @type spec :: {t, config}

  @typedoc "Whichever configuration is expected by the adapter."
  @type config :: any

  # @type handler :: (message, metadata -> :ok | :skip | {:ok, term} | {:error, term})

  @callback child_spec(config) :: Supervisor.child_spec()

  # @callback subscribe(config, topic_id, subscription_id, handler) ::
  #             :ok | {:error, :already_exists} | {:error, term}

  @callback publish(
              config,
              topic :: Gazet.topic(),
              message :: Gazet.message(),
              metadata :: Gazet.metadata()
            ) :: :ok | {:error, reason :: any}

  @optional_callbacks child_spec: 1

  @spec child_spec(t | spec) :: Supervisor.child_spec() | nil
  def child_spec({adapter, config}) when is_atom(adapter) do
    if function_exported?(adapter, :child_spec, 1) do
      adapter.child_spec(config)
    else
      nil
    end
  end

  @spec publish(
          t | spec,
          topic :: Gazet.topic(),
          message :: Gazet.message(),
          metadata :: Gazet.metadata()
        ) :: :ok | {:error, reason :: any}
  def publish({adapter, config}, topic, message, metadata) when is_atom(adapter) do
    adapter.publish(config, topic, message, metadata)
  end

  def publish(adapter, topic, message, metadata) when is_atom(adapter) do
    adapter.publish(nil, topic, message, metadata)
  end
end
