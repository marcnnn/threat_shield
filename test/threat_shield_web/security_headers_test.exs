defmodule ThreatShieldWeb.SecurityHeadersTest do
  use ThreatShieldWeb.ConnCase, async: true

  test "pages send a Content-Security-Policy header", %{conn: conn} do
    conn = get(conn, ~p"/users/log_in")

    assert [policy] = get_resp_header(conn, "content-security-policy")
    assert policy =~ "default-src 'self'"
    assert policy =~ "frame-ancestors 'self'"
    refute policy =~ "openai"

    # Phoenix 1.8 no longer sends X-Frame-Options; frame-ancestors replaces it
    assert get_resp_header(conn, "x-frame-options") == []
  end
end
