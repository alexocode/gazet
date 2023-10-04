defmodule Gazet.Subscriber.Generic do
  use GenServer

  alias Gazet.Subscriber

  def child_spec(%Subscriber{adapter_opts: opts} = subscriber) do
    Supervisor.child_spec(
      %{
        id: subscriber.id,
        start: {__MODULE__, :start_link, [subscriber]}
      },
      opts[:child_spec] || []
    )
  end

  def start_link(%Subscriber{} = subscriber) do
    GenServer.start_link(__MODULE__, subscriber, subscriber.adapter_opts[:start_opts] || [])
  end

  def init(%Subscriber{module: module} = subscriber) do
    with {:ok, config} <- module.init(subscriber) do
      {
        :ok,
        %{subscriber | config: config},
        {:continue, {:on_start, subscriber.adapter_opts[:on_start]}}
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
