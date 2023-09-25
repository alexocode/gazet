defmodule Gazet.Adapter.Noop do
  @behaviour Gazet.Adapter

  @impl true
  def publish(_message, _config), do: :ok

  @impl true
  def subscriber_spec({_module, opts}, _config) do
    %{
      id: opts[:id],
      start: {__MODULE__, :start_nothing, []}
    }
  end

  @doc false
  def start_nothing, do: :ignore
end
