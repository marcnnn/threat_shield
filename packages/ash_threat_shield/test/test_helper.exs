{:ok, _} = AshThreatShield.TestRepo.start_link()
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(AshThreatShield.TestRepo, :manual)
