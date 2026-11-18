defmodule ThreatShield.AccountsTest do
  use ThreatShield.DataCase

  # Registrations without URL builders log that they send no email
  @moduletag :capture_log

  import ThreatShield.AccountsFixtures

  alias AshAuthentication.Jwt
  alias ThreatShield.Accounts
  alias ThreatShield.Accounts.{ApiKey, Membership, User}
  alias ThreatShield.OrganisationsFixtures

  defp token_valid?(token), do: match?({:ok, _, _}, Jwt.verify(token, :threat_shield))

  defp confirmation_url_context, do: url_context(%{confirm: &"[TOKEN]#{&1}[TOKEN]"})

  describe "get_user_by_email/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email!("unknown@example.com", authorize?: false)
    end

    test "returns the user if the email exists, ignoring the case" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email!(String.upcase(to_string(user.email)),
                 authorize?: false
               )
    end
  end

  describe "get_user!/2" do
    test "raises if id is invalid" do
      user = user_fixture()

      assert_raise Ash.Error.Invalid, fn ->
        Accounts.get_user!(0, actor: user)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id, actor: user)
    end
  end

  describe "register_user/2" do
    test "stores the first and the last name" do
      attrs = valid_user_attributes(%{first_name: "Ada", last_name: "Lovelace"})

      assert {:ok, %User{first_name: "Ada", last_name: "Lovelace"}} =
               Accounts.register_user(attrs)
    end

    test "limits the names to the column size" do
      attrs = valid_user_attributes(%{first_name: String.duplicate("x", 41)})

      assert {:error, error} = Accounts.register_user(attrs)
      assert "should be at most 40 character(s)" in errors_on(error).first_name
    end

    test "requires email and password to be set" do
      {:error, error} = Accounts.register_user(%{accept_toc: true})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(error)
    end

    test "validates email and password when given" do
      {:error, error} =
        Accounts.register_user(%{email: "not valid", password: "not valid", accept_toc: true})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(error)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)

      {:error, error} =
        Accounts.register_user(%{email: too_long, password: too_long, accept_toc: true})

      assert "should be at most 160 character(s)" in errors_on(error).email
      assert "should be at most 72 character(s)" in errors_on(error).password
    end

    test "validates email uniqueness, ignoring the case" do
      %{email: email} = user_fixture()

      {:error, error} = Accounts.register_user(valid_user_attributes(%{email: email}))
      assert "has already been taken" in errors_on(error).email

      upcased = String.upcase(to_string(email))
      {:error, error} = Accounts.register_user(valid_user_attributes(%{email: upcased}))
      assert "has already been taken" in errors_on(error).email
    end

    test "requires the acceptance of the terms" do
      {:error, error} = Accounts.register_user(valid_user_attributes(%{accept_toc: false}))
      assert "must be accepted" in errors_on(error).accept_toc
    end

    test "registers users with a hashed password and a session token" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert to_string(user.email) == email
      assert is_binary(user.hashed_password)
      assert user.hashed_password != valid_user_password()
      assert is_nil(user.confirmed_at)
      assert token_valid?(user.__metadata__.token)
    end

    test "sends the confirmation instructions with the given URL builder" do
      email = unique_user_email()

      {:ok, _user} =
        Accounts.register_user(
          valid_user_attributes(email: email),
          url_context(%{confirm: &"https://test/confirm/#{&1}"})
        )

      assert_received {:email, %{to: [{_, ^email}], text_body: body}}
      assert body =~ "https://test/confirm/"
    end

    test "sends no email without a URL builder" do
      {:ok, _user} = Accounts.register_user(valid_user_attributes())
      refute_received {:email, _}
    end
  end

  describe "sign_in_user/3" do
    test "fails for an unknown email" do
      assert {:error, _} = Accounts.sign_in_user("unknown@example.com", "hello world!")
    end

    test "fails for a wrong password" do
      user = user_fixture()
      assert {:error, _} = Accounts.sign_in_user(user.email, "invalid password")
    end

    test "returns the user with a session token" do
      %{id: id} = user = user_fixture()

      assert {:ok, %User{id: ^id} = signed_in} =
               Accounts.sign_in_user(user.email, valid_user_password())

      assert token_valid?(signed_in.__metadata__.token)
    end
  end

  describe "confirmation" do
    test "confirms the user once with the token from the email" do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.request_confirmation(user.email, url_context(%{confirm: url}))
        end)

      assert {:ok, %User{confirmed_at: %DateTime{}}} = Accounts.confirm_user(token)
      assert {:error, _} = Accounts.confirm_user(token)
    end

    test "does not confirm with an invalid token" do
      assert {:error, _} = Accounts.confirm_user("invalid")
    end

    test "sends no instructions to a confirmed user or an unknown address" do
      user = confirmed_user_fixture()

      :ok = Accounts.request_confirmation(user.email, confirmation_url_context())
      :ok = Accounts.request_confirmation("unknown@example.com", confirmation_url_context())

      refute_received {:email, _}
    end
  end

  describe "password reset" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.request_password_reset(user.email, url_context(%{reset_password: url}))
        end)

      %{user: user, token: token}
    end

    test "finds the user by the reset token", %{user: %{id: id}, token: token} do
      assert {:ok, %User{id: ^id}} = Accounts.get_user_by_reset_token(token)
      assert {:ok, nil} = Accounts.get_user_by_reset_token("invalid")
    end

    test "does not accept other tokens of the user", %{user: user} do
      assert {:ok, nil} = Accounts.get_user_by_reset_token(user.__metadata__.token)
    end

    test "sets the new password and signs the user out everywhere", %{user: user, token: token} do
      session = user.__metadata__.token

      {:ok, _} =
        Accounts.reset_user_password(user, %{
          reset_token: token,
          password: "new valid password",
          password_confirmation: "new valid password"
        })

      assert {:ok, _} = Accounts.sign_in_user(user.email, "new valid password")
      refute token_valid?(session)
      assert {:ok, nil} = Accounts.get_user_by_reset_token(token)
    end

    test "revokes the API keys of the user", %{user: user, token: token} do
      api_key = api_key_fixture(user)
      other_key = api_key_fixture(user_fixture())

      {:ok, _} =
        Accounts.reset_user_password(user, %{
          reset_token: token,
          password: "new valid password",
          password_confirmation: "new valid password"
        })

      assert {:error, _} = Accounts.sign_in_with_api_key(api_key)
      assert {:ok, _} = Accounts.sign_in_with_api_key(other_key)
    end

    test "validates the token and the password", %{user: user, token: token} do
      {:error, error} =
        Accounts.reset_user_password(user, %{
          reset_token: user.__metadata__.token,
          password: "too short",
          password_confirmation: "does not match"
        })

      assert %{
               reset_token: ["is not valid"],
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(error)

      other_user = user_fixture()

      {:error, error} =
        Accounts.reset_user_password(other_user, %{
          reset_token: token,
          password: "new valid password",
          password_confirmation: "new valid password"
        })

      assert %{reset_token: ["is not valid"]} = errors_on(error)
    end
  end

  describe "change_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    defp change_password(user, attrs, opts) do
      user
      |> Ash.Changeset.for_update(:change_password, attrs, opts)
      |> Ash.update()
    end

    test "validates the current password and the confirmation", %{user: user} do
      {:error, error} =
        change_password(
          user,
          %{
            current_password: "invalid",
            password: "new valid password",
            password_confirmation: "other password"
          },
          actor: user
        )

      assert %{
               current_password: ["is not valid"],
               password_confirmation: ["does not match password"]
             } = errors_on(error)
    end

    test "updates the password and signs the user out everywhere", %{user: user} do
      session = user.__metadata__.token

      {:ok, _user} =
        Accounts.change_user_password(
          user,
          %{
            current_password: valid_user_password(),
            password: "new valid password",
            password_confirmation: "new valid password"
          },
          actor: user
        )

      assert {:ok, _} = Accounts.sign_in_user(user.email, "new valid password")
      assert {:error, _} = Accounts.sign_in_user(user.email, valid_user_password())
      refute token_valid?(session)
    end

    test "revokes the API keys of the user", %{user: user} do
      api_key = api_key_fixture(user)
      other_key = api_key_fixture(user_fixture())

      {:ok, _user} =
        Accounts.change_user_password(
          user,
          %{
            current_password: valid_user_password(),
            password: "new valid password",
            password_confirmation: "new valid password"
          },
          actor: user
        )

      assert {:error, _} = Accounts.sign_in_with_api_key(api_key)
      assert {:ok, _} = Accounts.sign_in_with_api_key(other_key)
    end
  end

  describe "change_user_email/4" do
    setup do
      %{user: user_fixture()}
    end

    defp request_change(user, email, password \\ valid_user_password(), opts \\ []) do
      Accounts.change_user_email(
        user,
        email,
        password,
        [actor: user] ++ url_context(%{confirm_email_change: &"[TOKEN]#{&1}[TOKEN]"}) ++ opts
      )
    end

    test "validates the current password and a change", %{user: user} do
      {:error, error} = request_change(user, user.email, "invalid")

      assert %{current_password: ["is not valid"], email: ["did not change"]} =
               errors_on(error)
    end

    test "validates the address", %{user: user} do
      {:error, error} = request_change(user, "with spaces")
      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(error)

      %{email: taken} = user_fixture()
      {:error, error} = request_change(user, taken)
      assert %{email: ["has already been taken"]} = errors_on(error)
    end

    test "changes the address when the link sent to it is followed", %{user: user} do
      email = unique_user_email()

      {:ok, unchanged} = request_change(user, email)
      assert unchanged.email == user.email

      assert_received {:email, %{to: [{_, ^email}], text_body: body}}
      [_, token | _] = String.split(body, "[TOKEN]")

      assert {:ok, changed} = Accounts.confirm_user_email_change(user, token, actor: user)
      assert to_string(changed.email) == email
      assert changed.confirmed_at

      assert {:error, _} = Accounts.confirm_user_email_change(changed, token, actor: changed)
    end

    test "does not apply the token to another user", %{user: user} do
      {:ok, _} = request_change(user, unique_user_email())
      assert_received {:email, %{text_body: body}}
      [_, token | _] = String.split(body, "[TOKEN]")

      other_user = user_fixture()

      assert {:error, _} =
               Accounts.confirm_user_email_change(other_user, token, actor: other_user)

      assert to_string(Accounts.get_user!(other_user.id, actor: other_user).email) ==
               to_string(other_user.email)
    end
  end

  describe "API keys" do
    setup do
      user = user_fixture()
      expires_at = DateTime.add(DateTime.utc_now(), 30, :day)
      {:ok, api_key} = Accounts.create_api_key(expires_at, actor: user)
      %{user: user, api_key: api_key}
    end

    test "sign in the user of the key", %{user: %{id: id}, api_key: api_key} do
      plaintext = api_key.__metadata__.plaintext_api_key
      assert plaintext =~ "threatshield_"

      assert {:ok, %User{id: ^id} = user} = Accounts.sign_in_with_api_key(plaintext)
      assert user.__metadata__.using_api_key?
    end

    test "do not sign in with a wrong or expired key", %{user: user, api_key: api_key} do
      assert {:error, _} = Accounts.sign_in_with_api_key("threatshield_invalid")

      plaintext = api_key.__metadata__.plaintext_api_key
      assert {:error, _} = Accounts.sign_in_with_api_key(plaintext <> "x")

      expired_at = DateTime.add(DateTime.utc_now(), -1, :second)
      {:ok, expired} = Accounts.create_api_key(expired_at, actor: user)
      assert {:error, _} = Accounts.sign_in_with_api_key(expired.__metadata__.plaintext_api_key)
    end

    test "are deleted when they have expired", %{user: user, api_key: %{id: id}} do
      expired_at = DateTime.add(DateTime.utc_now(), -1, :second)
      {:ok, _expired} = Accounts.create_api_key(expired_at, actor: user)

      Accounts.delete_expired_api_keys()

      assert [%ApiKey{id: ^id}] = Ash.read!(ApiKey, actor: user)
    end

    test "are visible only to their user", %{user: user, api_key: %{id: id}} do
      assert [%ApiKey{id: ^id}] = Ash.read!(ApiKey, actor: user)
      assert [] = Ash.read!(ApiKey, actor: user_fixture())
    end

    test "can not create further keys", %{api_key: api_key} do
      {:ok, api_user} = Accounts.sign_in_with_api_key(api_key.__metadata__.plaintext_api_key)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.create_api_key(DateTime.add(DateTime.utc_now(), 1, :day),
                 actor: api_user
               )
    end
  end

  describe "user policies" do
    setup do
      owner = user_fixture()
      organisation = OrganisationsFixtures.organisation_fixture(owner)
      member = user_fixture()

      Ash.create!(
        Membership,
        %{user_id: member.id, organisation_id: organisation.id, role: :viewer},
        action: :create,
        authorize?: false
      )

      %{owner: owner, member: member, stranger: user_fixture()}
    end

    test "a user reads itself and the members of its organisations", %{
      owner: owner,
      member: member,
      stranger: stranger
    } do
      ids = fn actor -> User |> Ash.read!(actor: actor) |> Enum.map(& &1.id) |> Enum.sort() end

      assert ids.(owner) == Enum.sort([owner.id, member.id])
      assert ids.(member) == Enum.sort([owner.id, member.id])
      assert ids.(stranger) == [stranger.id]
    end

    test "nobody reads users without an actor", %{owner: owner} do
      assert {:ok, []} = Ash.read(User)
      assert {:error, %Ash.Error.Invalid{}} = Accounts.get_user(owner.id)
      assert {:ok, nil} = Accounts.get_user_by_email(owner.email)
    end

    test "a user loads the organisations of the session", %{owner: owner} do
      assert %User{organisations: [_]} = Ash.load!(owner, :organisations, actor: owner)
    end

    test "a user changes only itself", %{owner: owner, member: member} do
      attrs = %{
        current_password: valid_user_password(),
        password: "new valid password",
        password_confirmation: "new valid password"
      }

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.change_user_password(member, attrs, actor: owner)

      assert {:error, %Ash.Error.Forbidden{}} = Accounts.change_user_password(member, attrs)

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.change_user_email(member, unique_user_email(), valid_user_password(),
                 actor: owner
               )

      assert {:ok, _} = Accounts.change_user_password(member, attrs, actor: member)
    end

    test "only AshAuthentication works with the tokens", %{owner: owner} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.read(ThreatShield.Accounts.Token, actor: owner)
    end
  end
end
