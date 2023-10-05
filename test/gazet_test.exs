defmodule GazetTest do
  use ExUnit.Case, async: true

  import Mox

  alias Gazet.Adapter.Mox, as: MoxAdapter

  doctest Gazet, import: true

  setup :verify_on_exit!

  @gazet %Gazet{adapter: {MoxAdapter, some: "config"}, topic: :my_topic, name: MyGazet}

  describe "child_spec/1" do
    test "invokes the adapter's `child_spec/1` function" do
      child_spec = %{what_we: {:expected, make_ref()}}

      expect(MoxAdapter, :child_spec, fn adapter_spec ->
        assert adapter_spec == %Gazet.Adapter{
                 module: MoxAdapter,
                 name: MyGazet.Adapter,
                 topic: @gazet.topic,
                 config: elem(@gazet.adapter, 1)
               }

        child_spec
      end)

      assert Gazet.child_spec(@gazet) == child_spec
    end
  end

  describe "publish/3" do
    test "invokes the adapter's `publish/2` function" do
      data = %{my: "message", data: make_ref()}
      metadata = %{my: "unique", metadata: make_ref()}
      ref = make_ref()

      expect(MoxAdapter, :publish, fn adapter_spec, message ->
        assert adapter_spec == %Gazet.Adapter{
                 module: MoxAdapter,
                 name: MyGazet.Adapter,
                 topic: @gazet.topic,
                 config: elem(@gazet.adapter, 1)
               }

        assert message == %Gazet.Message{
                 data: data,
                 metadata: metadata
               }

        {:error, {:ref, ref}}
      end)

      assert Gazet.publish(@gazet, data, metadata) == {:error, {:ref, ref}}
    end
  end

  describe "subscriber_spec/2" do
    test "invokes the adapter's `subscriber_spec/2` function" do
      subscriber = %Gazet.Subscriber{module: SomeSubsciber, id: :my_subscriber, source: @gazet}
      ref = make_ref()

      expect(MoxAdapter, :subscriber_spec, fn adapter_spec, subscriber_spec ->
        assert adapter_spec == %Gazet.Adapter{
                 module: MoxAdapter,
                 name: MyGazet.Adapter,
                 topic: @gazet.topic,
                 config: elem(@gazet.adapter, 1)
               }

        assert subscriber_spec == subscriber

        %{id: ref}
      end)

      assert Gazet.subscriber_spec(@gazet, subscriber) == %{id: ref}
    end
  end
end
