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

    assert [Date.range(~D[2025-01-02], ~D[2025-01-31])] ==
             Zeitraum.differenz(~m[2025-01], ~D[2025-01-01])

    assert [
             Date.range(~D[2024-12-30], ~D[2024-12-31]),
             Date.range(~D[2025-01-02], ~D[2025-01-05]),
             Date.range(~D[2025-01-14], ~D[2025-01-19])
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

  describe "DateRange-native Operationen" do
    test "differenz/2 gibt Date.Range zurück" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-10])
      b = Date.range(~D[2025-01-04], ~D[2025-01-06])

      result = Zeitraum.differenz(a, b)

      assert [
               Date.range(~D[2025-01-01], ~D[2025-01-03]),
               Date.range(~D[2025-01-07], ~D[2025-01-10])
             ] == result
    end

    test "differenz/2 kein Overlap" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-05])
      b = Date.range(~D[2025-01-10], ~D[2025-01-15])

      assert [a] == Zeitraum.differenz(a, b)
    end

    test "differenz/2 komplett abgedeckt" do
      a = Date.range(~D[2025-01-03], ~D[2025-01-05])
      b = Date.range(~D[2025-01-01], ~D[2025-01-10])

      assert [] == Zeitraum.differenz(a, b)
    end

    test "differenz/2 links abgeschnitten" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-10])
      b = Date.range(~D[2025-01-01], ~D[2025-01-05])

      assert [Date.range(~D[2025-01-06], ~D[2025-01-10])] == Zeitraum.differenz(a, b)
    end

    test "differenz/2 rechts abgeschnitten" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-10])
      b = Date.range(~D[2025-01-06], ~D[2025-01-15])

      assert [Date.range(~D[2025-01-01], ~D[2025-01-05])] == Zeitraum.differenz(a, b)
    end

    test "differenz/2 mit Listen von Date.Ranges" do
      basis = [Date.range(~D[2025-01-01], ~D[2025-01-10])]

      abzug = [
        Date.range(~D[2025-01-03], ~D[2025-01-04]),
        Date.range(~D[2025-01-08], ~D[2025-01-08])
      ]

      result = Zeitraum.differenz(basis, abzug)

      assert [
               Date.range(~D[2025-01-01], ~D[2025-01-02]),
               Date.range(~D[2025-01-05], ~D[2025-01-07]),
               Date.range(~D[2025-01-09], ~D[2025-01-10])
             ] == result
    end

    test "vereinigung/1 gibt Date.Range zurück" do
      ranges = [
        Date.range(~D[2025-01-01], ~D[2025-01-05]),
        Date.range(~D[2025-01-03], ~D[2025-01-08]),
        Date.range(~D[2025-01-15], ~D[2025-01-20])
      ]

      result = Zeitraum.vereinigung(ranges)

      assert [
               Date.range(~D[2025-01-01], ~D[2025-01-08]),
               Date.range(~D[2025-01-15], ~D[2025-01-20])
             ] == result
    end

    test "vereinigung/1 mergt angrenzende Ranges" do
      ranges = [
        Date.range(~D[2025-01-01], ~D[2025-01-05]),
        Date.range(~D[2025-01-06], ~D[2025-01-10])
      ]

      assert [Date.range(~D[2025-01-01], ~D[2025-01-10])] == Zeitraum.vereinigung(ranges)
    end

    test "vereinigung/2 gibt Date.Range zurück" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-05])
      b = Date.range(~D[2025-01-03], ~D[2025-01-08])

      assert Date.range(~D[2025-01-01], ~D[2025-01-08]) == Zeitraum.vereinigung(a, b)
    end

    test "vereinigung/2 nicht überlappend gibt Tupel zurück" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-03])
      b = Date.range(~D[2025-01-10], ~D[2025-01-12])

      assert {a, b} == Zeitraum.vereinigung(a, b)
    end

    test "ueberschneidung/2 gibt Date.Range zurück" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-10])
      b = Date.range(~D[2025-01-05], ~D[2025-01-15])

      assert Date.range(~D[2025-01-05], ~D[2025-01-10]) == Zeitraum.ueberschneidung(a, b)
    end

    test "ueberschneidung/2 gibt nil bei keiner Überschneidung" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-05])
      b = Date.range(~D[2025-01-10], ~D[2025-01-15])

      assert nil == Zeitraum.ueberschneidung(a, b)
    end

    test "ueberschneidung/2 identische Ranges" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-05])

      assert a == Zeitraum.ueberschneidung(a, a)
    end

    test "ueberlagere/1 mit Date.Ranges gibt Date.Range-Zeiträume zurück" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-05])
      b = Date.range(~D[2025-01-03], ~D[2025-01-08])

      ergebnis =
        Zeitraum.ueberlagere([a, b])
        |> Enum.sort_by(& &1.zeitraum.first, Date)

      expected_z1 = Date.range(~D[2025-01-01], ~D[2025-01-02])
      expected_z2 = Date.range(~D[2025-01-03], ~D[2025-01-05])
      expected_z3 = Date.range(~D[2025-01-06], ~D[2025-01-08])

      assert [
               %Ueberlagerung{zeitraum: ^expected_z1, elemente: [^a]},
               %Ueberlagerung{zeitraum: ^expected_z2, elemente: elemente},
               %Ueberlagerung{zeitraum: ^expected_z3, elemente: [^b]}
             ] = ergebnis

      assert a in elemente
      assert b in elemente
    end

    test "ueberlagere/1 einzelner Date.Range" do
      r = Date.range(~D[2025-01-01], ~D[2025-01-05])

      assert [%Ueberlagerung{zeitraum: ^r, elemente: [^r]}] = Zeitraum.ueberlagere([r])
    end

    test "ueberlagere/1 nicht überlappende Date.Ranges" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-03])
      b = Date.range(~D[2025-01-05], ~D[2025-01-07])

      ergebnis =
        Zeitraum.ueberlagere([a, b])
        |> Enum.sort_by(& &1.zeitraum.first, Date)

      assert [
               %Ueberlagerung{zeitraum: ^a, elemente: [^a]},
               %Ueberlagerung{zeitraum: ^b, elemente: [^b]}
             ] = ergebnis
    end

    test "ueberlagere/1 angrenzende Date.Ranges bleiben getrennt" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-03])
      b = Date.range(~D[2025-01-04], ~D[2025-01-06])

      ergebnis =
        Zeitraum.ueberlagere([a, b])
        |> Enum.sort_by(& &1.zeitraum.first, Date)

      assert [
               %Ueberlagerung{zeitraum: ^a, elemente: [^a]},
               %Ueberlagerung{zeitraum: ^b, elemente: [^b]}
             ] = ergebnis
    end

    test "ueberlagere/1 identische Date.Ranges" do
      r = Date.range(~D[2025-01-01], ~D[2025-01-05])

      assert [%Ueberlagerung{zeitraum: ^r, elemente: [^r, ^r]}] =
               Zeitraum.ueberlagere([r, r])
    end

    test "ueberlagere/1 Gesamtdauer bleibt erhalten mit Date.Ranges" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-07])
      b = Date.range(~D[2025-01-03], ~D[2025-01-05])

      gesamt_vorher = Zeitraum.dauer(a, :days)

      gesamt_nachher =
        Zeitraum.ueberlagere([a, b])
        |> Enum.map(&Zeitraum.dauer(&1, :days))
        |> Enum.sum()

      assert gesamt_vorher == gesamt_nachher
    end

    test "ueberschneidung?/2 mit Date.Ranges" do
      assert Zeitraum.ueberschneidung?(
               Date.range(~D[2025-01-01], ~D[2025-01-05]),
               Date.range(~D[2025-01-03], ~D[2025-01-08])
             )

      refute Zeitraum.ueberschneidung?(
               Date.range(~D[2025-01-01], ~D[2025-01-05]),
               Date.range(~D[2025-01-06], ~D[2025-01-08])
             )

      # Angrenzend an letztem Tag: a.last == b.first → true
      assert Zeitraum.ueberschneidung?(
               Date.range(~D[2025-01-01], ~D[2025-01-05]),
               Date.range(~D[2025-01-05], ~D[2025-01-08])
             )
    end

    test "teil_von?/2 mit Date.Ranges" do
      assert Zeitraum.teil_von?(
               Date.range(~D[2025-01-03], ~D[2025-01-05]),
               Date.range(~D[2025-01-01], ~D[2025-01-10])
             )

      refute Zeitraum.teil_von?(
               Date.range(~D[2025-01-01], ~D[2025-01-10]),
               Date.range(~D[2025-01-03], ~D[2025-01-05])
             )

      # Gleicher Range ist Teil von sich selbst
      assert Zeitraum.teil_von?(
               Date.range(~D[2025-01-01], ~D[2025-01-05]),
               Date.range(~D[2025-01-01], ~D[2025-01-05])
             )
    end

    test "compare/2 mit Date.Ranges" do
      assert :lt ==
               Zeitraum.compare(
                 Date.range(~D[2025-01-01], ~D[2025-01-05]),
                 Date.range(~D[2025-01-02], ~D[2025-01-05])
               )

      assert :eq ==
               Zeitraum.compare(
                 Date.range(~D[2025-01-01], ~D[2025-01-05]),
                 Date.range(~D[2025-01-01], ~D[2025-01-05])
               )

      assert :gt ==
               Zeitraum.compare(
                 Date.range(~D[2025-01-02], ~D[2025-01-05]),
                 Date.range(~D[2025-01-01], ~D[2025-01-05])
               )

      # Gleicher Start, kürzerer Range ist :lt
      assert :lt ==
               Zeitraum.compare(
                 Date.range(~D[2025-01-01], ~D[2025-01-03]),
                 Date.range(~D[2025-01-01], ~D[2025-01-05])
               )
    end

    test "beginnt_vor?/2, beginnt_nach?/2 mit Date.Ranges" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-05])
      b = Date.range(~D[2025-01-03], ~D[2025-01-08])

      assert Zeitraum.beginnt_vor?(a, b)
      refute Zeitraum.beginnt_nach?(a, b)
      refute Zeitraum.beginnt_vor?(a, a)
    end

    test "endet_vor?/2, endet_nach?/2 mit Date.Ranges" do
      a = Date.range(~D[2025-01-01], ~D[2025-01-05])
      b = Date.range(~D[2025-01-03], ~D[2025-01-08])

      assert Zeitraum.endet_vor?(a, b)
      refute Zeitraum.endet_nach?(a, b)
      refute Zeitraum.endet_vor?(a, a)
    end

    test "dauer/2 mit Date.Range" do
      range = Date.range(~D[2025-01-01], ~D[2025-01-07])

      assert 7 == Zeitraum.dauer(range, :days)
      assert 168 == Zeitraum.dauer(range, :hours)
      assert 1 == Zeitraum.dauer(range, :weeks)
    end

    test "dauer/2 mit Date.Range rechnet Monate, Jahre und kleine Einheiten wie Timex" do
      assert 1 == Zeitraum.dauer(~m[2025-02], :months)
      assert 1 == Zeitraum.dauer(Date.range(~D[2024-01-01], ~D[2024-12-31]), :years)
      assert 86_400_000 == Zeitraum.dauer(~D[2025-01-01], :milliseconds)
    end

    test "gemischte Eingaben ergeben Date.Ranges" do
      result = Zeitraum.differenz(Date.range(~D[2025-01-01], ~D[2025-01-10]), ~v[2025-01])
      assert Enum.all?(result, &match?(%Date.Range{}, &1))

      result = Zeitraum.vereinigung([Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-03]])
      assert Enum.all?(result, &match?(%Date.Range{}, &1))
    end

    test "gemischte Eingaben mit einem Interval fallen auf Interval zurück" do
      intervall = Shared.Zeitperiode.new(~N[2025-01-03 12:00:00], ~N[2025-01-04 12:00:00])

      result = Zeitraum.differenz(Date.range(~D[2025-01-01], ~D[2025-01-10]), intervall)
      assert Enum.all?(result, &match?(%Timex.Interval{}, &1))

      result = Zeitraum.vereinigung([Date.range(~D[2025-01-01], ~D[2025-01-05]), intervall])
      assert Enum.all?(result, &match?(%Timex.Interval{}, &1))
    end

    test "Enum.sort mit Date.Ranges über Zeitraum.compare" do
      ranges = [
        Date.range(~D[2025-01-10], ~D[2025-01-15]),
        Date.range(~D[2025-01-01], ~D[2025-01-05]),
        Date.range(~D[2025-01-01], ~D[2025-01-03])
      ]

      sorted = Enum.sort(ranges, Zeitraum)

      assert [
               Date.range(~D[2025-01-01], ~D[2025-01-03]),
               Date.range(~D[2025-01-01], ~D[2025-01-05]),
               Date.range(~D[2025-01-10], ~D[2025-01-15])
             ] == sorted
    end
  end
end
