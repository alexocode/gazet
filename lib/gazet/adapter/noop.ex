defmodule Gazet.Adapter.Noop do
  @behaviour Gazet.Adapter

  @impl true
  def publish(_adapter, _message), do: :ok

  @impl true
  def subscriber_child_spec(_adapter, %Gazet.Subscriber{id: id}) do
    %{
      id: id,
      start: {__MODULE__, :start_nothing, []}
    }
  end

  @doc false
  def start_nothing, do: :ignore
end
