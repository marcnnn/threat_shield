defmodule ThreatShield.Checks.PlatformAdmin do
  @moduledoc """
  Authorizes if the actor has the global role `platform_admin`.
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "the actor is a platform administrator"

  @impl true
  def match?(%{global_roles: roles}, _context, _opts) when is_list(roles),
    do: "platform_admin" in roles

  def match?(_actor, _context, _opts), do: false
end
