defmodule ThreatShield.Accounts.UserNotifierTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias ThreatShield.Accounts.UserNotifier

  test "a sender returns :ok and logs a failed delivery" do
    assert UserNotifier.sender_result({:ok, %Swoosh.Email{}}) == :ok

    log =
      capture_log(fn -> assert UserNotifier.sender_result({:error, :timeout}) == :ok end)

    assert log =~ "Sending an email failed: :timeout"
  end
end
