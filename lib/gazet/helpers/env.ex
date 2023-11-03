defaults = [
  at: nil,
  app: :gazet,
  key_in_context: :env,
  strategy: :replace
]

defmodule Gazet.Test.EnvHelpers do
  @moduledoc """
  ## Usage
  ### Inline

      import Gazet.EnvHelpers

      test "only has a changed application environment in the given function" do
        old_value = Application.get_env(:custom_app, :some_key)

        with_env_for(:gazet, [some_key: "some config"], fn ->
          new_value = Application.get_env(:custom_app, :some_key)

          assert new_value != old_value
          assert new_value == "some config"
        end)

        assert Application.get_env(:gazet, :some_key) == old_value
      end

  ### Setup - Using the defaults

      import Gazet.EnvHelpers

      setup :maybe_overwrite_env

      @tag env: [some_key: "configuration"]
      test "sets the config in #{inspect(defaults[:app])}" do
        assert Application.get_env(#{inspect(defaults[:app])}, :some_key) == "some config"
      end

  ### Setup - With a custom app and key

      import Gazet.EnvHelpers

      setup context do
        maybe_overwrite_env(context, app: :custom_app, key_in_context: :config)
      end

      @tag config: [some_key: "some config"]
      test "sets the :custom_app configuration" do
        assert Application.get_env(:custom_app, :my) == "some config"
      end
  """

  @type app :: atom
  @type key :: atom
  @type env :: any
  @type strategy :: :merge | :replace

  @type opts :: [
          at: nil | key,
          app: app,
          key_in_context: key,
          strategy: strategy
        ]

  @default_opts defaults

  @doc """
  Overwrites the application environment if the given key is set in the context.

  For usage see the moduledoc.

  ## Defaults
  #{Enum.map_join(@default_opts, "\n", fn {key, value} -> "#{key}: #{inspect(value)}" end)}
  """
  @spec maybe_overwrite_env(context, opts) :: context when context: map
  def maybe_overwrite_env(context, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    {app, opts} = Keyword.pop!(opts, :app)
    {key, opts} = Keyword.pop!(opts, :key_in_context)

    cond do
      context[:async] and not is_nil(context[key]) ->
        raise RuntimeError,
              "Overwriting the application environment in async tests is highly discouraged. " <>
                "Since the application environment is global doing so in an async test can lead to undefined behaviour and flaky tests."

      not is_nil(context[key]) ->
        overwrite_env(app, context[key], opts)

      true ->
        :noop
    end

    context
  end

  @default_overwrite_env_opts Keyword.take(@default_opts, [:at, :strategy])
  @doc """
  Overwrites the application environment for the given application with the given values.

  ## Defaults
  #{Enum.map_join(@default_overwrite_env_opts, "\n", fn {key, value} -> "#{key}: #{inspect(value)}" end)}
  """
  @spec overwrite_env(app, overwrites :: keyword(env), opts) :: :ok
  def overwrite_env(app, overwrites, opts \\ []) do
    opts = Keyword.merge(@default_overwrite_env_opts, opts)
    at = Keyword.fetch!(opts, :at)
    strategy = Keyword.fetch!(opts, :strategy)

    do_overwrite_env(strategy, app, at, overwrites)
  end

  defp do_overwrite_env(strategy, app, at, overwrites) when not is_nil(at) do
    do_overwrite_env(strategy, app, nil, [{at, overwrites}])
  end

  defp do_overwrite_env(strategy, app, nil, overwrites) do
    old_envs =
      Enum.map(overwrites, fn {key, env} ->
        old_env = fetch_then_overwrite(strategy, app, key, env)
        {key, old_env}
      end)

    ExUnit.Callbacks.on_exit(fn ->
      Enum.each(old_envs, fn {key, old_env} ->
        revert_overwrite(strategy, app, key, old_env)
      end)
    end)
  end

  with_env_opts = quote do: [strategy: strategy]
  @default_with_env_opts [strategy: @default_opts[:strategy]]

  @doc """
  Overwrites the application environment, calls the given function, and reverts the overwrite.

  For usage examples see the moduledoc.

  Overwrites the env for app `#{inspect(@default_opts[:app])}`. If you want to overwrite the
  env for a different app use `with_env_for/3` or `with_env_for/4`.
  """
  @spec with_env(overwrites :: keyword(env), function :: (-> any)) :: :ok
  @spec with_env(
          overwrites :: keyword(env),
          function :: (-> any),
          opts :: unquote(with_env_opts)
        ) :: :ok
  @spec with_env(key, env, function :: (-> any)) :: :ok
  @spec with_env(key, env, function :: (-> any), opts :: unquote(with_env_opts)) :: :ok
  def with_env(overwrites, function) when is_list(overwrites) and is_function(function, 0) do
    with_env(overwrites, function, @default_with_env_opts)
  end

  def with_env(overwrites, function, opts)
      when is_list(overwrites) and is_function(function, 0) and is_list(opts) do
    with_env_for(unquote(@default_opts[:app]), overwrites, function, opts)
  end

  def with_env(key, env, function)
      when is_atom(key) and is_list(env) and is_function(function, 0) do
    with_env(key, env, function, @default_with_env_opts)
  end

  def with_env(key, env, function, opts)
      when is_atom(key) and is_list(env) and is_function(function, 0) and is_list(opts) do
    with_env_for(unquote(@default_opts[:app]), key, env, function, opts)
  end

  @doc """
  Overwrites the application environment for the given app and then calls the
  given function, and reverts the overwrite.

  For usage examples see the moduledoc.
  """
  @spec with_env_for(app, overwrites :: keyword(env), function :: (-> any)) :: :ok
  @spec with_env_for(
          app,
          overwrites :: keyword(env),
          function :: (-> any),
          opts :: unquote(with_env_opts)
        ) :: :ok
  @spec with_env_for(app, key, env, function :: (-> any)) :: :ok
  @spec with_env_for(app, key, env, function :: (-> any), opts :: unquote(with_env_opts)) ::
          :ok
  def with_env_for(app, overwrites, function)
      when is_atom(app) and is_list(overwrites) and is_function(function, 0) do
    with_env_for(app, overwrites, function, @default_with_env_opts)
  end

  def with_env_for(app, overwrites, function, opts)
      when is_atom(app) and is_list(overwrites) and is_function(function, 0) and is_list(opts) do
    strategy = Keyword.fetch!(opts, :strategy)

    old_env = fetch_then_overwrite(strategy, app, overwrites)
    function.()
    revert_overwrite(strategy, app, old_env)

    :ok
  end

  def with_env_for(app, key, env, function, opts)
      when is_atom(app) and is_atom(key) and is_list(env) and is_function(function, 0) and
             is_list(opts) do
    with_env_for(app, [{key, env}], function, opts)
  end

  def fetch_then_overwrite(strategy, app, overwrites) do
    for {key, env} <- overwrites do
      {key, fetch_then_overwrite(strategy, app, key, env)}
    end
  end

  defp fetch_then_overwrite(strategy, app, key, env) do
    fetched_env = Application.fetch_env(app, key)

    case strategy do
      :replace ->
        Application.put_env(app, key, env)

      :merge ->
        Application.put_env(app, key, merge(fetched_env, env))
    end

    fetched_env
  end

  defp merge({:ok, fetched_env}, env), do: Keyword.merge(fetched_env, env)
  defp merge(:error, env), do: env

  defp revert_overwrite(strategy, app, overwritten) do
    for {key, fetched_env} <- overwritten do
      revert_overwrite(strategy, app, key, fetched_env)
    end
  end

  defp revert_overwrite(_strategy, app, key, {:ok, env}) do
    Application.put_env(app, key, env)
  end

  defp revert_overwrite(_strategy, app, key, :error) do
    Application.delete_env(app, key)
  end
end
