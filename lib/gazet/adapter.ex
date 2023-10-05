schema =
  Gazet.Options.schema!(
    module: [
      type: :atom,
      required: true,
      doc: "A module implementing the `Gazet.Adapter` behaviour."
    ],
    name: [
      type: :atom,
      required: true,
      doc: "The name of the Adapter (used for Supervision)."
    ],
    topic: [
      type: {:or, [:atom, :string]},
      required: true,
      doc: "The topic the Adapter needs to publish and subscribe to."
    ],
    config: [
      type: :keyword_list,
      required: false,
      doc: "Adapter specific configuration."
    ]
  )

defmodule Gazet.Adapter do
  use Gazet.Blueprint,
    schema: schema,
    typespecs_for: [:config]

  @typedoc "A module implementing this behaviour with optional additional config."
  @type t :: module | {module, config}

  @type opts :: [unquote(Gazet.Options.typespec(schema))]

  @callback child_spec(blueprint) :: Supervisor.child_spec()

  @callback publish(blueprint, message :: Gazet.Message.t()) :: :ok | {:error, reason :: any}
  @callback subscriber_child_spec(blueprint, subscriber :: Gazet.Subscriber.blueprint()) ::
              Supervisor.child_spec()

  @optional_callbacks child_spec: 1

  @spec child_spec(blueprint) :: Supervisor.child_spec() | nil
  def child_spec(%__MODULE__{module: module} = adapter) do
    if function_exported?(module, :child_spec, 1) do
      module.child_spec(adapter)
    else
      nil
    end
  end

  @spec publish(blueprint, message :: Gazet.Message.t()) :: :ok | {:error, reason :: any}
  def publish(%__MODULE__{module: module} = adapter, %Gazet.Message{} = message) do
    module.publish(adapter, message)
  end

  @spec subscriber_child_spec(blueprint, subscriber :: Gazet.Subscriber.blueprint()) ::
          Supervisor.child_spec()
  def subscriber_child_spec(
        %__MODULE__{module: module} = adapter,
        %Gazet.Subscriber{} = subscriber
      ) do
    module.subscriber_child_spec(adapter, subscriber)
  end

  @spec blueprint!(t | blueprint, opts) :: blueprint | no_return
  def blueprint!({module, config}, opts) when is_atom(module) do
    raw_blueprint =
      opts
      |> Keyword.put(:module, module)
      |> Keyword.update(:config, config, &Keyword.merge(config, &1))

    Gazet.Blueprint.build!(__MODULE__, raw_blueprint)
  end

  def blueprint!(module, opts) when is_atom(module) do
    blueprint!({module, []}, opts)
  end

  def blueprint!(%__MODULE__{} = adapter, opts) do
    Gazet.Blueprint.build!(adapter, opts)
  end
end
