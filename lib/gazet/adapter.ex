defmodule Gazet.Adapter do
  @typedoc "A module implementing this behaviour."
  @type t :: module
  @type spec :: {t, config}

  @typedoc "A keyword list of configuration values, some shared, some specific for each adapter."
  @type config :: [shared_config | {atom, term}]
  @type shared_config ::
          {:name, Gazet.name()}
          | {:topic, Gazet.topic()}

  @callback child_spec(config) :: Supervisor.child_spec()

  @callback publish(message :: Gazet.Message.t(), config) :: :ok | {:error, reason :: any}
  @callback subscriber_spec(subscriber :: Gazet.Subscriber.spec(), config) ::
              Supervisor.child_spec()

  @optional_callbacks child_spec: 1

  @spec child_spec(spec) :: Supervisor.child_spec() | nil
  def child_spec({adapter, config}) when is_atom(adapter) do
    if function_exported?(adapter, :child_spec, 1) do
      adapter.child_spec(config)
    else
      nil
    end
  end

  @spec publish(spec, message :: Gazet.Message.t()) :: :ok | {:error, reason :: any}
  def publish({adapter, config}, %Gazet.Message{} = message) when is_atom(adapter) do
    adapter.publish(config, message)
  end

  @spec subscriber_spec(spec, subscriber :: Gazet.Subscriber.spec()) :: Supervisor.child_spec()
  def subscriber_spec({adapter, config}, %Gazet.Subscriber{} = subscriber)
      when is_atom(adapter) do
    adapter.subscriber_spec(subscriber, config)
  end

  @spec spec(t | spec, config) :: spec
  def spec({adapter, config}, extra_config) when is_atom(adapter) do
    {adapter, Keyword.merge(config, extra_config)}
  end

  def spec(adapter, extra_config) when is_atom(adapter) do
    {adapter, extra_config}
  end
end
