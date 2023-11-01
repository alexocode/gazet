defmodule Gazet.Adapter.Local do
  alias Gazet.Message
  alias Gazet.Adapter
  alias Gazet.Subscriber

  @behaviour Gazet.Adapter

  @impl true
  def child_spec(%Adapter{name: name}) do
    Registry.child_spec(
      keys: :unique,
      name: name,
      partitions: System.schedulers_online()
    )
  end

  @impl true
  @registered_pids_spec [{{:_, :"$1", :_}, [], [:"$1"]}]
  def publish(%Adapter{name: name, topic: topic}, %Message{} = message) do
    name
    |> Registry.select(@registered_pids_spec)
    |> Enum.each(&send(&1, {:message, topic, message}))
  end

  @impl true
  def subscriber_child_spec(%Adapter{} = adapter, %Subscriber{} = subscriber) do
    Subscriber.Generic.child_spec(subscriber,
      start_opts: [name: subscriber_name(adapter, subscriber)]
    )
  end

  defp subscriber_name(%Adapter{name: adapter_name}, %Subscriber{id: subscriber_id}) do
    {:via, Registry, {adapter_name, subscriber_id}}
  end
end
