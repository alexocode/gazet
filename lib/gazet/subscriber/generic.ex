schema =
  Gazet.Options.schema!(
    child_spec: [type: :keyword_list, default: [], doc: "Overrides for `child_spec/1`"],
    start_opts: [type: :keyword_list, default: [], doc: "Options for `GenServer.start_link/3`"],
    on_start: [
      type: {:or, [:mfa, {:fun, 0}, {:fun, 1}]},
      required: false,
      doc:
        "Function to be invoked on start, needs to conform to `t:on_start`. When this returns an error the `GenServer` `stop`s with the error reason."
    ]
  )

schema_keys = Gazet.Options.map(schema, fn key, _spec -> key end)

defmodule Gazet.Subscriber.Generic do
  @moduledoc """
  ## `Subscriber.adapter_opts[:server]`
  #{Gazet.Options.docs(schema)}
  """
  use GenServer

  alias Gazet.Subscriber

  @schema schema

  @type opts :: [unquote(Gazet.Options.typespec(schema))]
  @type on_start ::
          (Subscriber.blueprint() -> :ok | {:ok, Subscriber.spec()} | {:error, reason :: any})

  for key <- schema_keys do
    @spec with_opt(
            Subscriber.blueprint(),
            unquote(key),
            unquote(Gazet.Options.typespec(schema, key))
          ) :: Subscriber.blueprint()
  end

  def with_opt(%Subscriber{} = subscriber, key, value) when key in unquote(schema_keys) do
    update_in(subscriber.adapter_opts[:server], fn
      nil -> [{key, value}]
      server_opts when is_list(server_opts) -> Keyword.put(server_opts, key, value)
    end)
  end

  @spec with_opts(Subscriber.blueprint(), opts) :: Subscriber.blueprint()
  def with_opts(%Subscriber{} = subscriber, server_opts) do
    Enum.reduce(server_opts, subscriber, fn {key, value}, subscriber ->
      with_opt(subscriber, key, value)
    end)
  end

  @spec child_spec(Subscriber.blueprint(), server_opts :: opts) :: Supervisor.child_spec()
  def child_spec(%Subscriber{} = subscriber, server_opts \\ []) do
    {:ok, subscriber} =
      subscriber
      |> with_opts(server_opts)
      |> with_validated_opts()

    Supervisor.child_spec(
      %{
        id: subscriber.id,
        start: {__MODULE__, :start_link, [subscriber]}
      },
      opt(subscriber, :child_spec)
    )
  end

  @spec start_link(Subscriber.blueprint(), server_opts :: opts) ::
          GenServer.on_start() | Gazet.Options.error()
  def start_link(%Subscriber{} = subscriber, server_opts \\ []) do
    subscriber = with_opts(subscriber, server_opts)

    with {:ok, subscriber} <- with_validated_opts(subscriber) do
      GenServer.start_link(
        __MODULE__,
        subscriber,
        opt(subscriber, :start_opts)
      )
    end
  end

  defp with_validated_opts(%Subscriber{adapter_opts: adapter_opts} = subscriber) do
    server_opts = adapter_opts[:server] || []

    if server_opts[:__validated__] == true do
      {:ok, subscriber}
    else
      with {:ok, server_opts} <- Gazet.Options.validate(server_opts, @schema) do
        server_opts = Keyword.put(server_opts, :__validated__, true)

        {:ok, put_in(subscriber.adapter_opts[:server], server_opts)}
      end
    end
  end

  def opt(%Subscriber{adapter_opts: adapter_opts}, key) do
    get_in(adapter_opts, [:server, key])
  end

  def init(%Subscriber{module: module} = subscriber) do
    with {:ok, config} <- module.init(subscriber) do
      {
        :ok,
        %{subscriber | config: config},
        {:continue, {:on_start, opt(subscriber, :on_start)}}
      }
    end
  end

  def handle_continue({:on_start, nil}, %Subscriber{} = subscriber) do
    {:noreply, subscriber}
  end

  def handle_continue({:on_start, on_start}, %Subscriber{} = subscriber) do
    on_start
    |> case do
      function when is_function(function, 0) ->
        function.()

      function when is_function(function, 1) ->
        function.(subscriber)

      {module, function, args} ->
        apply(module, function, [subscriber | args])
    end
    |> case do
      :ok -> {:noreply, subscriber}
      {:ok, %Subscriber{} = subscriber} -> {:noreply, subscriber}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_info(
        {:message, topic, %Gazet.Message{} = message},
        %Subscriber{module: module} = subscriber
      ) do
    case module.handle_message(topic, message.data, message.metadata, subscriber.config) do
      fine when fine in [:ok, :skip] ->
        {:noreply, subscriber}

      {:error, reason} ->
        handle_error(reason, topic, message, subscriber)
    end
  end

  defp handle_error(reason, topic, message, %{module: module} = subscriber) do
    case module.handle_error(reason, topic, message.data, message.metadata, subscriber.config) do
      fine when fine in [:ok, :skip] ->
        {:noreply, subscriber}

      {:error, reason} ->
        {:stop, reason}
    end
  end
end
