defmodule Gazet.Env do
  @moduledoc false

  @type env_spec :: {otp_app, module}
  @type otp_app :: atom

  @spec resolve(env_spec | [env_spec]) :: keyword
  def resolve({otp_app, module}), do: resolve(otp_app, module)

  def resolve(env_specs) when is_list(env_specs) do
    Enum.reduce(env_specs, [], fn {otp_app, module}, merged ->
      merge(merged, otp_app, module)
    end)
  end

  @spec resolve(otp_app, module) :: keyword
  def resolve(otp_app, module) when is_atom(otp_app) and is_atom(module) do
    Application.get_env(otp_app, module, [])
  end

  @spec resolve(env_spec | [env_spec], allowed_keys :: [atom]) :: keyword
  def resolve(env_specs, allowed_keys) do
    env_specs
    |> resolve()
    |> Keyword.take(allowed_keys)
  end

  @spec resolve(otp_app, module, allowed_keys :: [atom]) :: keyword
  def resolve(otp_app, module, allowed_keys) when is_atom(otp_app) and is_atom(module) do
    otp_app
    |> resolve(module)
    |> Keyword.take(allowed_keys)
  end

  @spec merge(keyword | map, otp_app, module) :: keyword
  def merge(into, otp_app, module) when is_map(into) do
    into
    |> Map.to_list()
    |> merge(otp_app, module)
  end

  def merge(into, otp_app, module) when is_list(into) do
    Keyword.merge(into, resolve(otp_app, module))
  end
end
