defmodule Shared.Zeitraum.DateRangeTest do
  use ExUnit.Case, async: true

  alias Shared.Zeitraum.DateRange
  alias Shared.Zeitraum.Ueberlagerung

  describe "ueberlagere/1" do
    test "erzeugt keinen leeren Abschnitt, wenn ein Range endet und ein anderer am Folgetag beginnt" do
      monat = Date.range(~D[2025-01-01], ~D[2025-01-10])
      anfang = Date.range(~D[2025-01-01], ~D[2025-01-03])
      mitte = Date.range(~D[2025-01-04], ~D[2025-01-06])

      zeitraeume =
        [monat, anfang, mitte]
        |> DateRange.ueberlagere()
        |> Enum.map(& &1.zeitraum)

      assert [
               Date.range(~D[2025-01-01], ~D[2025-01-03]),
               Date.range(~D[2025-01-04], ~D[2025-01-06]),
               Date.range(~D[2025-01-07], ~D[2025-01-10])
             ] == zeitraeume
    end

    test "gibt für einen einzelnen Range genau einen Abschnitt zurück" do
      range = Date.range(~D[2025-01-01], ~D[2025-01-05])

      assert [%Ueberlagerung{zeitraum: ^range, elemente: [^range]}] =
               DateRange.ueberlagere([range])
    end

    test "gibt für eine leere Liste eine leere Liste zurück" do
      assert [] == DateRange.ueberlagere([])
    end
  end
end
