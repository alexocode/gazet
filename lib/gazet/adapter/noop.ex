defmodule Gazet.Adapter.Noop do
  @behaviour Gazet.Adapter

  @impl true
  def publish(_message, _config), do: :ok
end
