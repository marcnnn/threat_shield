defmodule ThreatShield.Checks.OrganisationRoleForCreate do
  @moduledoc """
  Authorizes a create action if the actor is a member of the organisation of the new
  record with a role that has the given right (see `ThreatShield.Accounts.Rights`).

  The organisation is the attribute `organisation_id` of the new record. For a record
  below the organisation, give the parent with `parent: {attribute, resource}`, e.g.
  `parent: {:threat_id, Threat}`. The parent resource must have an attribute or a
  calculation `organisation_id`.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias ThreatShield.Accounts.{Membership, Rights}

  @impl true
  def describe(opts) do
    "actor has the right #{inspect(opts[:right])} in the organisation of the new record"
  end

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, opts) do
    roles = Rights.roles(Keyword.fetch!(opts, :right))

    case organisation_id(changeset, opts[:parent]) do
      nil ->
        tool_listing?(changeset)

      org_id ->
        # This check is the authorization, so it reads without it.
        Membership
        |> Ash.Query.filter(
          user_id == ^actor.id and organisation_id == ^org_id and role in ^roles
        )
        |> Ash.exists?(authorize?: false)
    end
  end

  def match?(_actor, _context, _opts), do: false

  # ash_ai lists an MCP tool only if the actor may call it, and asks with an empty
  # input and this private context, which a client cannot set. The organisation of
  # the new record is unknown then; the call of the tool is authorized with its
  # input like any other create.
  defp tool_listing?(changeset),
    do: changeset.context[:private][:ash_ai_pre_check?] == true

  defp organisation_id(changeset, nil),
    do: Ash.Changeset.get_attribute(changeset, :organisation_id)

  defp organisation_id(changeset, {attribute, resource}) do
    case Ash.Changeset.get_attribute(changeset, attribute) do
      nil ->
        nil

      parent_id ->
        # The parent may belong to an organisation of which the actor is not a
        # member, so it is read without authorization.
        resource
        |> Ash.Query.filter(id == ^parent_id)
        |> Ash.Query.load(load_for(resource))
        |> Ash.read_one(authorize?: false)
        |> case do
          {:ok, %{organisation_id: org_id}} -> org_id
          _ -> nil
        end
    end
  end

  defp load_for(resource) do
    if Ash.Resource.Info.calculation(resource, :organisation_id), do: [:organisation_id], else: []
  end
end
