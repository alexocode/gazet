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
  use Gazet.Spec,
    schema: schema,
    typespecs_for: [:config]

  @typedoc "A module implementing this behaviour with optional additional config."
  @type t :: module | {module, config}

  @type opts :: [unquote(Gazet.Options.typespec(schema))]

  @callback child_spec(spec) :: Supervisor.child_spec()

  @callback publish(spec, message :: Gazet.Message.t()) :: :ok | {:error, reason :: any}
  @callback subscriber_child_spec(spec, subscriber :: Gazet.Subscriber.spec()) ::
              Supervisor.child_spec()

  @optional_callbacks child_spec: 1

  @spec child_spec(spec) :: Supervisor.child_spec() | nil
  def child_spec(%__MODULE__{module: module} = spec) do
    if function_exported?(module, :child_spec, 1) do
      module.child_spec(spec)
    else
      nil
    end
  end

  @spec publish(spec, message :: Gazet.Message.t()) :: :ok | {:error, reason :: any}
  def publish(%__MODULE__{module: module} = spec, %Gazet.Message{} = message) do
    module.publish(spec, message)
  end

  @spec subscriber_child_spec(spec, subscriber :: Gazet.Subscriber.spec()) ::
          Supervisor.child_spec()
  def subscriber_child_spec(%__MODULE__{module: module} = spec, %Gazet.Subscriber{} = subscriber) do
    module.subscriber_child_spec(spec, subscriber)
  end

  @spec spec!(t | spec, opts) :: spec | no_return
  def spec!({adapter, config}, opts) when is_atom(adapter) do
    raw_spec =
      opts
      |> Keyword.put(:module, adapter)
      |> Keyword.update(:config, config, &Keyword.merge(config, &1))

    Gazet.Spec.build!(__MODULE__, raw_spec)
  end

  def spec!(adapter, opts) when is_atom(adapter) do
    spec!({adapter, []}, opts)
  end

  def spec!(%__MODULE__{} = spec, opts) do
    Gazet.Spec.build!(spec, opts)
  end
end
