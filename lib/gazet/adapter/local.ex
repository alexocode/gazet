defmodule Gazet.Adapter.Local do
  alias Gazet.Message
  alias Gazet.Subscriber

  @behaviour Gazet.Adapter

  @impl true
  def child_spec(%{name: name}) do
    Registry.child_spec(
      keys: :duplicate,
      name: name,
      partitions: System.schedulers_online()
    )
  end

  @impl true
  def publish(%{name: name, topic: topic}, %Message{} = message) do
    Registry.dispatch(name, topic, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:message, topic, message})
    end)
  end

  @impl true
  def subscriber_spec(%{name: name, topic: topic}, %Subscriber{} = subscriber) do
    Subscriber.Generic.child_spec(subscriber,
      on_start: fn ->
        with {:ok, _} <- Registry.register(name, topic, :ignored) do
          :ok
        end
      end
    )
  end
end
