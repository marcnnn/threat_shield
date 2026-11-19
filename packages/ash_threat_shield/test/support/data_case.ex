defmodule AshThreatShield.DataCase do
  @moduledoc """
  The case of the tests that use the database of the test host. Each test runs in a
  sandbox transaction that is rolled back.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias AshThreatShield.TestRepo, as: Repo

      import AshThreatShield.DataCase
      import AshThreatShield.Test.Fixtures
    end
  end

  setup tags do
    pid =
      Sandbox.start_owner!(AshThreatShield.TestRepo,
        shared: not tags[:async]
      )

    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc """
  The field errors of an Ash error or changeset as a map of fields to messages.
  """
  def errors_on(%{errors: errors}) do
    for %{field: field} = error when not is_nil(field) <- errors, reduce: %{} do
      acc -> Map.update(acc, field, [message(error)], &(&1 ++ [message(error)]))
    end
  end

  defp message(%{message: message} = error) when is_binary(message) do
    vars = Map.get(error, :vars) || []

    Regex.replace(~r"%{(\w+)}", message, fn _, key ->
      vars |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end

  defp message(error), do: Exception.message(error)

  @doc """
  Asserts that the function raises because a record was not found for the actor,
  either because it does not exist or because the actor lacks the right.
  """
  def assert_not_found(fun) when is_function(fun, 0) do
    error = ExUnit.Assertions.assert_raise(Ash.Error.Invalid, fun)

    ExUnit.Assertions.assert(
      Enum.any?(error.errors, &match?(%Ash.Error.Query.NotFound{}, &1)),
      "expected a not found error, got: #{Exception.message(error)}"
    )

    error
  end
end
