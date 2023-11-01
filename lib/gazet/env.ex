defmodule Gazet.Env do
  @moduledoc false

  @type env_spec :: {otp_app :: atom, module :: module}

  @spec resolve(spec :: env_spec | [env_spec]) :: keyword
  def resolve(env_specs) do
    env_specs
    |> List.wrap()
    |> Enum.reduce([], fn {otp_app, module}, merged ->
      merge(merged, otp_app, module)
    end)
  end

  @spec resolve(spec :: env_spec | [env_spec], allowed_keys :: [atom]) :: keyword
  def resolve(env_specs, allowed_keys) do
    env_specs
    |> resolve()
    |> Keyword.take(allowed_keys)
  end

  @spec merge(keyword | map, otp_app :: atom, module :: atom) :: keyword
  def merge(into, otp_app, module) when is_map(into) do
    into
    |> Map.to_list()
    |> merge(otp_app, module)
  end

  def merge(into, otp_app, module) do
    env = Application.get_env(otp_app, module, [])

    Keyword.merge(into, env)
  end
end
