defmodule Gazet.Env do
  @moduledoc false

  @spec resolve([{otp_app :: atom, key :: atom}]) :: keyword
  def resolve(list) when is_list(list) do
    Enum.reduce(list, [], fn {otp_app, key}, merged ->
      merge(merged, otp_app, key)
    end)
  end

  @spec merge(keyword | map, otp_app :: atom, key :: atom) :: keyword
  def merge(into, otp_app, key) when is_map(into) do
    into
    |> Map.to_list()
    |> merge(otp_app, key)
  end

  def merge(into, otp_app, key) do
    Keyword.merge(into, Application.get_env(otp_app, key, []))
  end
end
