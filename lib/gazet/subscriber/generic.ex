defmodule Gazet.Subscriber.Generic do
  use GenServer

  alias Gazet.Subscriber

  @spec child_spec(Subscriber.blueprint(), start_opts :: GenServer.options()) ::
          Supervisor.child_spec()
  def child_spec(%Subscriber{} = subscriber, start_opts \\ []) do
    %{
      id: subscriber.id,
      start: {__MODULE__, :start_link, [subscriber, start_opts]},
      type: :worker,
      modules: [__MODULE__, subscriber.module]
    }
  end

  @spec start_link(Subscriber.blueprint(), start_opts :: GenServer.options()) ::
          GenServer.on_start() | Gazet.Options.error()
  def start_link(%Subscriber{} = subscriber, start_opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      subscriber,
      start_opts
    )
  end

  def init(%Subscriber{module: module} = subscriber) do
    with {:ok, context} <- module.init(subscriber) do
      {:ok, {subscriber, context}}
    end
  end

  def handle_info(
        {:message, topic, %Gazet.Message{} = message},
        {%Subscriber{module: module} = subscriber, context}
      ) do
    case module.handle_batch(topic, [{message.data, message.metadata}], context) do
      :ok ->
        {:noreply, {subscriber, context}}

      {:error, reason} ->
        {:stop, reason, {subscriber, context}}
    end
  end

end
