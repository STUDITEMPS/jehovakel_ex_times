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
  end

  describe "jetzt/0" do
    test "schneidet Millisekunden weg" do
      assert %DateTime{microsecond: {0, 0}} = Zeit.jetzt()
    end
  end
end
