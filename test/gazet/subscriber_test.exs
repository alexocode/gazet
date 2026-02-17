defmodule Gazet.SubscriberTest do
  use ExUnit.Case, async: true

  alias Gazet.Subscriber

  @source %Gazet{otp_app: :gazet, adapter: Gazet.Adapter.Noop, name: TestSourceGazet, topic: "test"}

  describe "use Gazet.Subscriber — defoverridable" do
    test "init/1 can be overridden and call super" do
      defmodule OverridingSubscriber do
        use Gazet.Subscriber,
          source: TestSourceGazet,
          otp_app: :gazet

        @impl Gazet.Subscriber
        def init(%Subscriber{} = blueprint) do
          {:ok, base_ctx} = super(blueprint)
          {:ok, {base_ctx, :extra}}
        end

        @impl Gazet.Subscriber
        def handle_batch(_topic, _batch, _ctx), do: :ok
      end

      blueprint = %Subscriber{
        module: OverridingSubscriber,
        source: @source,
        otp_app: :gazet,
        id: OverridingSubscriber,
        start_opts: [],
        subscriber_opts: :my_opts
      }

      assert {:ok, {:my_opts, :extra}} = OverridingSubscriber.init(blueprint)
    end
  end
end
