defmodule Gazet.Adapter do
  @typedoc "A module implementing this behaviour."
  @type t :: module
  @type spec :: {t, config}

  @typedoc "A keyword list of configuration values, some shared, some specific for each adapter."
  @type config :: [shared_config | {atom, term}]
  @type shared_config ::
          {:name, Gazet.name()}
          | {:topic, Gazet.topic()}

  # @type handler :: (message, metadata -> :ok | :skip | {:ok, term} | {:error, term})

  @callback child_spec(config) :: Supervisor.child_spec()

  # @callback subscribe(config, topic_id, subscription_id, handler) ::
  #             :ok | {:error, :already_exists} | {:error, term}

  @callback publish(
              config,
              message :: Gazet.message(),
              metadata :: Gazet.metadata()
            ) :: :ok | {:error, reason :: any}

  @optional_callbacks child_spec: 1

  @spec child_spec(spec) :: Supervisor.child_spec() | nil
  def child_spec({adapter, config}) when is_atom(adapter) do
    if function_exported?(adapter, :child_spec, 1) do
      adapter.child_spec(config)
    else
      nil
    end
  end

  @spec publish(
          spec,
          message :: Gazet.message(),
          metadata :: Gazet.metadata()
        ) :: :ok | {:error, reason :: any}
  def publish({adapter, config}, message, metadata) when is_atom(adapter) do
    adapter.publish(config, message, metadata)
  end

  @spec spec(t | spec, config) :: spec
  def spec({adapter, config}, extra_config) when is_atom(adapter) do
    {adapter, Keyword.merge(config, extra_config)}
  end

  def spec(adapter, extra_config) when is_atom(adapter) do
    {adapter, extra_config}
  end
end