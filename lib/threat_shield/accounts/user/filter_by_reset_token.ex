defmodule ThreatShield.Accounts.User.Preparations.FilterByResetToken do
  @moduledoc """
  Keeps the user that the password reset token in the argument `:reset_token` was
  issued for. Keeps nobody if the token is invalid, expired or revoked.
  """

  use Ash.Resource.Preparation

  alias AshAuthentication.{Info, Jwt}

  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    case primary_key(query, context) do
      {:ok, primary_key} -> Ash.Query.filter(query, ^primary_key)
      :error -> Ash.Query.filter(query, false)
    end
  end

  defp primary_key(query, context) do
    {:ok, strategy} = Info.strategy(query.resource, :password)
    reset_action = to_string(strategy.resettable.password_reset_action_name)

    with token when is_binary(token) <- Ash.Query.get_argument(query, :reset_token),
         {:ok, %{"act" => ^reset_action, "sub" => subject}, _resource} <-
           Jwt.verify(token, query.resource, Ash.Context.to_opts(context)),
         {:ok, primary_key} <- AshAuthentication.subject_to_primary_key(subject, query.resource) do
      {:ok, primary_key}
    else
      _ -> :error
    end
  end
end
