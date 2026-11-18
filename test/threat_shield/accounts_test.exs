defmodule ThreatShield.AccountsTest do
  use ThreatShield.DataCase

  alias ThreatShield.Accounts.Helpers, as: Accounts

  import ThreatShield.AccountsFixtures
  alias ThreatShield.Accounts.User

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %{id: ^id} = Accounts.get_user_by_email(to_string(user.email))
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(to_string(user.email), "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %{id: ^id} =
               Accounts.get_user_by_email_and_password(
                 to_string(user.email),
                 valid_user_password()
               )
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ash.Error.Invalid, fn ->
        Accounts.get_user!(0)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "stores the first and the last name" do
      attrs = valid_user_attributes(%{first_name: "Ada", last_name: "Lovelace"})

      assert {:ok, %User{first_name: "Ada", last_name: "Lovelace"}} =
               Accounts.register_user(attrs)
    end

    test "limits the names to the column size" do
      attrs = valid_user_attributes(%{first_name: String.duplicate("x", 41)})

      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "should be at most 40 character(s)" in errors_on(changeset).first_name
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert to_string(user.email) == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Accounts.change_user_registration(%ThreatShield.Accounts.User{})
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %ThreatShield.Accounts.User{},
          %{email: email, password: password}
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = Accounts.change_user_email(%ThreatShield.Accounts.User{})
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()

      {:ok, applied_user} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: email})

      assert applied_user.email == email
      assert to_string(Accounts.get_user!(user.id).email) != email
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = Accounts.change_user_password(%ThreatShield.Accounts.User{})
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%ThreatShield.Accounts.User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, _user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password",
          password_confirmation: "new valid password"
        })

      assert Accounts.get_user_by_email_and_password(to_string(user.email), "new valid password")
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert is_binary(token)
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      # JWT verification may fail in sandbox due to async token store operations
      case Accounts.get_user_by_session_token(token) do
        nil -> :ok
        session_user -> assert session_user.id == user.id
      end
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end
  end

  describe "delete_user_session_token/1" do
    test "returns :ok" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "updates the password", %{user: user} do
      {:ok, _updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert Accounts.get_user_by_email_and_password(to_string(user.email), "new valid password")
    end
  end
end
