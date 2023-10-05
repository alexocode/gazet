Mox.defmock(Gazet.Adapter.Mox, for: Gazet.Adapter)
Mox.defmock(Gazet.Adapter.MoxWithoutChildSpec, for: Gazet.Adapter, skip_optional_callbacks: true)

ExUnit.start()
