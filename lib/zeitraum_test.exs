defmodule Shared.ZeitraumTest do
  use ExUnit.Case

  import Shared.Week, only: [sigil_v: 2]
  import Shared.Month, only: [sigil_m: 2]

  alias Shared.Zeitraum
  alias Shared.Zeitraum.Ueberlagerung

  doctest Zeitraum, import: true

  test "differenz/2" do
    assert [] == Zeitraum.differenz(~D[2025-01-01], ~D[2025-01-01])
    assert [] == Zeitraum.differenz(~D[2025-01-01], ~m[2025-01])

    assert [Zeitraum.als_intervall(Date.range(~D[2025-01-02], ~D[2025-01-31]))] ==
             Zeitraum.differenz(~m[2025-01], ~D[2025-01-01])

    assert [
             Zeitraum.als_intervall(Date.range(~D[2024-12-30], ~D[2024-12-31])),
             Zeitraum.als_intervall(Date.range(~D[2025-01-02], ~D[2025-01-05])),
             Zeitraum.als_intervall(Date.range(~D[2025-01-14], ~D[2025-01-19]))
           ] ==
             Zeitraum.differenz([~v[2025-01], ~v[2025-03]], [
               ~D[2025-01-01],
               ~D[2025-01-08],
               ~D[2025-01-13]
             ])

    assert [] == Zeitraum.differenz([~D[2025-01-01], ~D[2025-01-13]], [~v[2025-01], ~v[2025-03]])
  end

  describe "ueberlagere/1" do
    import Shared.Zeitraum, only: [sigil_Z: 2]

    test "leere Liste ergibt leere Liste" do
      assert [] == Zeitraum.ueberlagere([])
    end

    test "einzelner Zeitraum" do
      assert [
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-01 00:00:00/2025-01-02 00:00:00],
                 elemente: [~D[2025-01-01]]
               }
             ] == Zeitraum.ueberlagere([~D[2025-01-01]])
    end

    test "nicht überlappende Zeiträume bleiben getrennt" do
      assert [
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-01 00:00:00/2025-01-02 00:00:00],
                 elemente: [~D[2025-01-01]]
               },
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-03 00:00:00/2025-01-04 00:00:00],
                 elemente: [~D[2025-01-03]]
               }
             ] == Zeitraum.ueberlagere([~D[2025-01-01], ~D[2025-01-03]])
    end

    test "direkt aneinander angrenzende Zeiträume bleiben getrennt" do
      assert [
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-01 00:00:00/2025-01-02 00:00:00],
                 elemente: [~D[2025-01-01]]
               },
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-02 00:00:00/2025-01-03 00:00:00],
                 elemente: [~D[2025-01-02]]
               }
             ] == Zeitraum.ueberlagere([~D[2025-01-01], ~D[2025-01-02]])
    end

    test "identische Zeiträume werden vollständig überlagert" do
      assert [
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-01 00:00:00/2025-01-02 00:00:00],
                 elemente: [~D[2025-01-01], ~D[2025-01-01]]
               }
             ] == Zeitraum.ueberlagere([~D[2025-01-01], ~D[2025-01-01]])
    end

    test "teilweise überlappende Zeiträume werden in drei Segmente aufgeteilt" do
      mo_bis_mi = ~Z[2025-01-06/2025-01-08]
      di_bis_do = ~Z[2025-01-07/2025-01-09]

      ergebnis =
        Zeitraum.ueberlagere([mo_bis_mi, di_bis_do])
        |> Enum.sort_by(& &1.zeitraum.from, NaiveDateTime)
        |> sortiere_elemente()

      assert [
               %Ueberlagerung{zeitraum: ~Z[2025-01-06/2025-01-07], elemente: [mo_bis_mi]},
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-07/2025-01-08],
                 elemente: [mo_bis_mi, di_bis_do]
               },
               %Ueberlagerung{zeitraum: ~Z[2025-01-08/2025-01-09], elemente: [di_bis_do]}
             ] == ergebnis
    end

    test "ein Zeitraum vollständig in einem anderen enthalten" do
      woche = ~v[2025-01]
      mittwoch = ~D[2025-01-01]

      ergebnis =
        Zeitraum.ueberlagere([woche, mittwoch])
        |> Enum.sort_by(& &1.zeitraum.from, NaiveDateTime)
        |> sortiere_elemente()

      assert [
               %Ueberlagerung{
                 zeitraum: ~Z[2024-12-30 00:00:00/2025-01-01 00:00:00],
                 elemente: [woche]
               },
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-01 00:00:00/2025-01-02 00:00:00],
                 elemente: [woche, mittwoch]
               },
               %Ueberlagerung{
                 zeitraum: ~Z[2025-01-02 00:00:00/2025-01-06 00:00:00],
                 elemente: [woche]
               }
             ] == ergebnis
    end

    test "drei überlappende Zeiträume" do
      a = ~Z[2025-01-06/2025-01-08]
      b = ~Z[2025-01-07/2025-01-09]
      c = ~Z[2025-01-08/2025-01-10]

      ergebnis =
        Zeitraum.ueberlagere([a, b, c])
        |> Enum.sort_by(& &1.zeitraum.from, NaiveDateTime)
        |> sortiere_elemente()

      assert [
               %Ueberlagerung{zeitraum: ~Z[2025-01-06/2025-01-07], elemente: [a]},
               %Ueberlagerung{zeitraum: ~Z[2025-01-07/2025-01-08], elemente: [a, b]},
               %Ueberlagerung{zeitraum: ~Z[2025-01-08/2025-01-09], elemente: [b, c]},
               %Ueberlagerung{zeitraum: ~Z[2025-01-09/2025-01-10], elemente: [c]}
             ] == ergebnis
    end

    test "Gesamtdauer bleibt erhalten" do
      woche = ~v[2025-01]
      mittwoch = ~D[2025-01-01]

      gesamt_vorher = Zeitraum.dauer(woche, :hours)

      gesamt_nachher =
        Zeitraum.ueberlagere([woche, mittwoch])
        |> Enum.map(&Zeitraum.dauer(&1, :hours))
        |> Enum.sum()

      assert gesamt_vorher == gesamt_nachher
    end

    defp sortiere_elemente(ueberlagerungen) do
      Enum.map(ueberlagerungen, fn %Ueberlagerung{} = u ->
        %{u | elemente: Enum.sort(u.elemente, Zeitraum)}
      end)
    end

    test "Ueberlagerung implementiert ZeitraumProtokoll" do
      [ueberlagerung] = Zeitraum.ueberlagere([~D[2025-01-01]])

      assert Zeitraum.als_intervall(ueberlagerung) == Zeitraum.als_intervall(~D[2025-01-01])
      assert Zeitraum.dauer(ueberlagerung, :hours) == 24
    end
  end
end
