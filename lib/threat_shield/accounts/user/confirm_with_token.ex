defmodule ThreatShield.Accounts.User.Actions.ConfirmWithToken do
  @moduledoc """
  Confirms the user that the confirmation token in the argument `:confirm` was
  issued for. The token is single use.
  """

  use Ash.Resource.Actions.Implementation

  alias AshAuthentication.{AddOn.Confirmation, Info}
  alias ThreatShield.Accounts.User

  @impl true
  def run(input, _opts, context) do
    {:ok, strategy} = Info.strategy(User, :confirm_new_user)
    token = Ash.ActionInput.get_argument(input, :confirm)

    Confirmation.Actions.confirm(strategy, %{"confirm" => token}, Ash.Context.to_opts(context))
  end
end
