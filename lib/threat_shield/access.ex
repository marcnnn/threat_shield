defmodule ThreatShield.Access do
  @moduledoc """
  Context-level access checks on top of the Ash resources.

  Every resource of the organisation hierarchy has a read action `:for_user`. It
  keeps the records of the organisations where the user is a member with one of the
  given roles. The roles come from a right of `ThreatShield.Members.Rights`; without
  a right, any membership is enough.

  This is an interim solution: the contexts call the actions with
  `authorize?: false` until the access rules are expressed as Ash policies.
  """

  require Ash.Query

  alias ThreatShield.Accounts.User
  alias ThreatShield.Members.Rights

  @all_roles [:owner, :editor, :viewer]

  @doc """
  Returns a query for the records of `resource` that the user may read, or may
  change with the given right.
  """
  def query(resource, %User{id: user_id}, right \\ nil) do
    Ash.Query.for_read(resource, :for_user, %{user_id: user_id, roles: roles(right)},
      authorize?: false
    )
  end

  @doc """
  Loads one record for the user. Raises `Ash.Error.Invalid` with an
  `Ash.Error.Query.NotFound` error if it does not exist or the user lacks the right.
  """
  def get!(resource, %User{} = user, id, right \\ nil, load \\ []) do
    resource
    |> query(user, right)
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(load)
    |> Ash.read_one!(authorize?: false, not_found_error?: true)
  end

  @doc """
  Like `get!/5`, but returns `{:ok, record}` or `{:error, :not_found}`.
  """
  def get(resource, %User{} = user, id, right \\ nil, load \\ []) do
    resource
    |> query(user, right)
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(load)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, record} -> {:ok, record}
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc """
  Returns the roles that have the right, or all roles for `nil`.
  """
  def roles(nil), do: @all_roles
  def roles(right) when is_atom(right), do: Rights.get_authorised_roles(right)
end
