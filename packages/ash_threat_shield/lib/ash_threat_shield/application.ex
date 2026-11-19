defmodule AshThreatShield.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # the cache of the AI suggestions of attribute values
      AshThreatShield.DynamicAttribute
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AshThreatShield.Supervisor)
  end
end
