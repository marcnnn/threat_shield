defmodule ThreatShield.Accounts.User.Actions.RequestConfirmation do
  @moduledoc """
  Sends new confirmation instructions to the user with the given address, if the
  user exists and is not confirmed yet. Always succeeds, so that the result does
  not tell whether an address is registered.
  """

  use Ash.Resource.Actions.Implementation

  alias AshAuthentication.{AddOn.Confirmation, Info}
  alias ThreatShield.Accounts.User

  require Logger

  @impl true
  def run(input, _opts, context) do
    email = Ash.ActionInput.get_argument(input, :email)

    case unconfirmed_user(email) do
      %User{} = user -> send_instructions(user, input, context)
      nil -> :ok
    end
  end

  defp unconfirmed_user(email) do
    User
    |> Ash.Query.set_context(%{private: %{ash_authentication?: true}})
    |> Ash.Query.for_read(:get_by_email, %{email: email})
    |> Ash.read_one()
    |> case do
      {:ok, %User{confirmed_at: nil} = user} -> user
      _ -> nil
    end
  end

  defp send_instructions(user, input, context) do
    {:ok, strategy} = Info.strategy(User, :confirm_new_user)
    opts = Ash.Context.to_opts(context)

    case Confirmation.confirmation_token(strategy, Ash.Changeset.new(user), user, opts) do
      {:ok, token} ->
        {sender, send_opts} = strategy.sender
        sender.send(user, token, Keyword.put(send_opts, :context, input.context))
        :ok

      _ ->
        Logger.warning("Could not generate a confirmation token for user #{user.id}")
        :ok
    end
  end
end
