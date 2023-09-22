defmodule Gazet.Adapter.Noop do
  @behaviour Gazet.Adapter

  @impl true
  def publish(_config, _message), do: :ok
end
