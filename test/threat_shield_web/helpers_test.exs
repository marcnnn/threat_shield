defmodule ThreatShieldWeb.HelpersTest do
  use ExUnit.Case, async: true

  import ThreatShieldWeb.Helpers

  describe "format_number/1" do
    test "groups thousands with a dot and rounds to whole numbers" do
      assert format_number(nil) == "-"
      assert format_number(0) == "0"
      assert format_number(999) == "999"
      assert format_number(1000) == "1.000"
      assert format_number(1_234_567) == "1.234.567"
      assert format_number(-1_234_567) == "-1.234.567"
      assert format_number(1234.5) == "1.235"
      assert format_number(0.4) == "0"
      assert format_number(Decimal.new("12345.49")) == "12.345"
      assert format_number("2500") == "2.500"
    end
  end

  describe "format_decimal/1" do
    test "keeps up to two decimal places" do
      assert format_decimal(nil) == "-"
      assert format_decimal(0.3) == "0,3"
      assert format_decimal(2.0) == "2"
      assert format_decimal(0.125) == "0,13"
      assert format_decimal(1234.5) == "1.234,5"
      assert format_decimal(-0.25) == "-0,25"
    end
  end

  describe "format_monetary_amount/2" do
    test "appends the currency" do
      assert format_monetary_amount(nil) == "-"
      assert format_monetary_amount(Decimal.new("1500000")) == "1.500.000 EUR"
      assert format_monetary_amount(42, "USD") == "42 USD"
    end
  end
end
