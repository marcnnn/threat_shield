defmodule ThreatShield.Analytics.RiskAnalyticsTest do
  use ExUnit.Case
  alias ThreatShield.Analytics.RiskAnalytics

  describe "risk analytics" do
    test "can handle empty lists" do
      assert 0.0 == RiskAnalytics.max_cost([])
      assert 0.0 == RiskAnalytics.max_frequency([])
    end
  end
end
