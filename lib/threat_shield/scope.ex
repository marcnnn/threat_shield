defmodule ThreatShield.Scope do
  @moduledoc """
  Defined a scope for domain objects. The membership of the user is the
  `:actor_membership` of the organisation, if it is loaded (with the user as the
  actor).
  """
  alias ThreatShield.Accounts.User
  alias ThreatShield.Accounts.{Membership, Organisation}
  alias ThreatShield.ThreatManagement.System

  defstruct [
    :id,
    :user,
    :organisation,
    :membership,
    :system,
    :asset,
    :threat
  ]

  def for(%User{} = user, %Organisation{} = org) do
    id = to_string(org.id)

    %__MODULE__{
      id: id,
      user: user,
      organisation: org,
      membership: membership(org)
    }
  end

  def for(%User{} = user, %Organisation{} = org, context) when is_list(context) do
    id = to_string(org.id)

    %__MODULE__{
      id: id,
      user: user,
      organisation: org,
      membership: membership(org),
      threat: context[:threat],
      system: context[:system],
      asset: context[:asset]
    }
  end

  @doc """
  Defined a scope for a system and optionally a threat for this system.
  """
  def for_system(
        %User{} = user,
        %Organisation{} = org,
        %System{} = system
      ) do
    id = to_string(org.id) <> "-" <> to_string(system.id)

    %__MODULE__{
      id: id,
      user: user,
      organisation: org,
      membership: membership(org),
      system: system
    }
  end

  defp membership(%Organisation{actor_membership: %Membership{} = membership}), do: membership
  defp membership(_organisation), do: nil
end
