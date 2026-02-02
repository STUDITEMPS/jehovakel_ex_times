defmodule Shared.ZeitTest do
  use ExUnit.Case, async: true
  import Support.TimeAssertionHelper

  alias Shared.Zeit
  doctest Shared.Zeit

  import Shared.Zeit.Sigil
  doctest Shared.Zeit.Sigil

  describe "mit_deutscher_zeitzone/1" do
    test "Zeitumstellung von Winterzeit auf Sommerzeit" do
      zeit_in_luecke = ~N[2018-03-25 02:00:00]

      assert {:error, {:could_not_resolve_timezone, "Europe/Berlin", _timestamp, :wall}} =
               Shared.Zeit.mit_deutscher_zeitzone(zeit_in_luecke)
    end
  end

  describe "parse/1" do
    test "parse Date Time mit Offset" do
      assert Zeit.parse("2019-04-18T10:00:00+02:00")
             |> entspricht_timestamp?("2019-04-18T10:00:00+02:00")
    end

    test "parse Date Time mit Zeitzone" do
      assert Zeit.parse("2018-10-03T10:20:42Z")
             |> entspricht_timestamp?("2018-10-03T10:20:42Z")
    end

    test "parse Date Time ohne Zeitzone" do
      assert Zeit.parse("2018-10-03T10:20:42")
             |> Timex.to_datetime("Etc/UTC")
             |> entspricht_timestamp?("2018-10-03T10:20:42Z")
    end

    test "parse date-only string" do
      assert Zeit.parse("2025-01-15") == ~N[2025-01-15 00:00:00]
    end

    test "parse date-only string at year boundary" do
      assert Zeit.parse("2024-12-31") == ~N[2024-12-31 00:00:00]
      assert Zeit.parse("2025-01-01") == ~N[2025-01-01 00:00:00]
    end

    test "parse invalid date raises ArgumentError" do
      assert_raise ArgumentError, ~r/Invalid date\/time format/, fn ->
        Zeit.parse("not-a-date")
      end
    end

    test "parse invalid date with wrong month raises ArgumentError" do
      assert_raise ArgumentError, ~r/Invalid date\/time format/, fn ->
        Zeit.parse("2025-13-01")
      end
    end
  end

  describe "jetzt/0" do
    test "schneidet Millisekunden weg" do
      assert %DateTime{microsecond: {0, 0}} = Zeit.jetzt()
    end
  end
end
