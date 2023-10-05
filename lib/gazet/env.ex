defmodule Gazet.Env do
  @moduledoc false

  @spec resolve([{otp_app :: atom, module}]) :: keyword
  def resolve(list) when is_list(list) do
    Enum.reduce(list, [], fn {otp_app, module}, merge_into ->
      env = Application.get_env(otp_app, module, [])

      Keyword.merge(merge_into, env)
    end)
  end
end
