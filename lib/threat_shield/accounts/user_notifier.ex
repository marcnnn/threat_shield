defmodule ThreatShield.Accounts.UserNotifier do
  import Swoosh.Email

  alias ThreatShield.Mailer
  alias ThreatShield.Accounts.Invite

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(to_string(recipient))
      |> from({"ThreatShield", "no-reply@mg.inspired.consulting"})
      |> reply_to({"ThreatShield", "threatshield@inspired.consulting"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email. They go to the new address.
  """
  def deliver_update_email_instructions(user, new_email, url) do
    deliver(new_email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver organisation invites. `url` is the link that accepts the invite; the web
  layer builds it from the token of the invite.
  """
  def deliver_invite(%Invite{} = invite, url) do
    deliver(invite.email, "You have been invited to an organisation in ThreatShield", """
    Hi,

    You have been invited to join #{invite.organisation.name} on ThreatShield 🙂 Follow the link below to accept the invite:

    #{url}

    Best regards,
    Your ThreatShield team
    https://threatshield.eu
    """)
  end
end
