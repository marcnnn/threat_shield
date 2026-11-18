defmodule ThreatShield.Accounts.User.Changes.RevokeApiKeys do
  @moduledoc """
  Deletes all API keys of the user, in the transaction of the action. A new password
  ends every access that was granted with the old one: `log_out_everywhere` revokes
  the tokens, this change the API keys.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias ThreatShield.Accounts.ApiKey

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      # The action has authorized the change of the password: the user itself, or
      # the holder of a reset token, who has no actor. The keys of the user go with
      # the old password.
      ApiKey
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.bulk_destroy(:destroy, %{},
        authorize?: false,
        strategy: [:atomic, :stream],
        return_errors?: true
      )
      |> case do
        %Ash.BulkResult{status: :success} -> {:ok, user}
        %Ash.BulkResult{errors: errors} -> {:error, errors}
      end
    end)
  end
end
