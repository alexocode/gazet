defmodule Gazet.Subscriber.GenericTest do
  use ExUnit.Case, async: true

  alias Gazet.Subscriber
  alias Gazet.Subscriber.Generic
  alias Gazet.Message

  @source %Gazet{otp_app: :gazet, adapter: Gazet.Adapter.Noop, name: TestGazet, topic: "test"}

  defmodule TestSubscriber do
    @behaviour Gazet.Subscriber

    def config do
      [module: __MODULE__, source: TestGazet, id: "test-subscriber"]
    end

    def init(%Subscriber{}), do: {:ok, :no_context}

    def handle_batch(topic, batch, context) do
      send(context, {:handle_batch, topic, batch})
      :ok
    end
  end

  defp subscriber do
    %Subscriber{
      module: TestSubscriber,
      id: "test-sub",
      source: @source,
      otp_app: :gazet,
      start_opts: [],
      subscriber_opts: nil
    }
  end

  describe "child_spec/2" do
    test "captures subscriber in start args so the process can be restarted" do
      spec = Generic.child_spec(subscriber())
      {_module, _fun, args} = spec.start
      assert [%Subscriber{}, _opts] = args
    end

    test "uses subscriber.id as the child id" do
      spec = Generic.child_spec(subscriber())
      assert spec.id == "test-sub"
    end
  end

  describe "handle_info/2 — {:message, topic, message}" do
    test "dispatches to handle_batch with a single-element batch" do
      {:ok, pid} = Generic.start_link(subscriber(), [])

      data = %{event: "something"}
      metadata = %{ts: DateTime.utc_now()}
      message = %Message{data: data, metadata: metadata}

      # Override context to this test process so we get the callback.
      # Capture self() before replace_state — the callback runs in the GenServer process.
      test_pid = self()
      :sys.replace_state(pid, fn {sub, _ctx} -> {sub, test_pid} end)

      send(pid, {:message, "test", message})

      assert_receive {:handle_batch, "test", [{^data, ^metadata}]}
    end

    test "stops the process when handle_batch returns an error" do
      {:ok, pid} = Generic.start_link(subscriber(), [])
      Process.unlink(pid)
      ref = Process.monitor(pid)

      defmodule ErrorSubscriber do
        @behaviour Gazet.Subscriber
        def config, do: []
        def init(%Subscriber{}), do: {:ok, nil}
        def handle_batch(_topic, _batch, _context), do: {:error, :intentional}
      end

      failing_sub = %Subscriber{subscriber() | module: ErrorSubscriber}
      :sys.replace_state(pid, fn {_sub, ctx} -> {failing_sub, ctx} end)

      send(pid, {:message, "test", %Message{data: %{}, metadata: %{}}})

      assert_receive {:DOWN, ^ref, :process, ^pid, :intentional}
    end
  end
end
