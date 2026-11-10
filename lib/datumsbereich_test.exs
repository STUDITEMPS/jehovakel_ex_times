defmodule Shared.DatumsbereichTest do
  use ExUnit.Case, async: true

  import Shared.Month, only: [sigil_m: 2]
  import Shared.Week, only: [sigil_v: 2]

  alias Shared.Datumsbereich
  alias Shared.Datumsbereich.Ueberlagerung

  doctest Datumsbereich
  doctest Ueberlagerung

  defmodule MitDefaultKeys do
    use Shared.Datumsbereich
    defstruct [:beginn, :ende]
  end

  defmodule MitStartKey do
    use Shared.Datumsbereich
    defstruct [:start, :ende]
  end

  defmodule MitEigenenKeys do
    use Shared.Datumsbereich, beginn: :gueltig_ab, ende: :gueltig_bis
    defstruct [:gueltig_ab, :gueltig_bis]
  end

  defmodule MitDatumsbereichKey do
    use Shared.Datumsbereich, datumsbereich: :datumsbereich
    defstruct [:datumsbereich, :betrag]
  end

  describe "use Shared.Datumsbereich" do
    test "verwendet die Default-Keys beginn und ende" do
      struct = %MitDefaultKeys{beginn: ~D[2025-07-01], ende: ~D[2025-07-14]}

      assert Date.range(~D[2025-07-01], ~D[2025-07-14]) == MitDefaultKeys.to_date_range(struct)
    end

    test "verwendet start, wenn es kein Feld beginn gibt" do
      struct = %MitStartKey{start: ~D[2025-07-01], ende: ~D[2025-07-14]}

      assert Date.range(~D[2025-07-01], ~D[2025-07-14]) == MitStartKey.to_date_range(struct)
    end

    test "verwendet eigene Keys" do
      struct = %MitEigenenKeys{gueltig_ab: ~D[2025-01-01], gueltig_bis: ~D[2025-12-31]}

      assert Date.range(~D[2025-01-01], ~D[2025-12-31]) == MitEigenenKeys.to_date_range(struct)
    end

    test "akzeptiert für beginn und ende nur Dates" do
      struct = %MitDefaultKeys{beginn: ~N[2025-07-01 12:00:00], ende: ~N[2025-07-04 00:00:00]}

      assert_raise FunctionClauseError, fn -> MitDefaultKeys.to_date_range(struct) end
    end

    test "übernimmt ein Date.Range aus dem datumsbereich-Key" do
      range = Date.range(~D[2025-02-01], ~D[2025-02-28])

      assert range ==
               MitDatumsbereichKey.to_date_range(%MitDatumsbereichKey{datumsbereich: range})
    end

    test "ruft to_date_range/1 des Structs im datumsbereich-Key auf" do
      urlaub = %MitDefaultKeys{beginn: ~D[2025-07-01], ende: ~D[2025-07-14]}

      assert Date.range(~D[2025-07-01], ~D[2025-07-14]) ==
               MitDatumsbereichKey.to_date_range(%MitDatumsbereichKey{datumsbereich: urlaub})

      assert Date.range(~D[2025-02-01], ~D[2025-03-31]) ==
               MitDatumsbereichKey.to_date_range(%MitDatumsbereichKey{
                 datumsbereich: Shared.Month.range(~m[2025-02], ~m[2025-03])
               })
    end

    test "wirft einen Fehler, wenn der datumsbereich-Key weder Date.Range noch to_date_range/1 hat" do
      assert_raise ArgumentError, ~r/implementiert kein to_date_range/, fn ->
        MitDatumsbereichKey.to_date_range(%MitDatumsbereichKey{datumsbereich: ~m[2025-02]})
      end
    end

    test "wirft einen Fehler, wenn die Default-Keys fehlen" do
      assert_raise ArgumentError, ~r/^:beginn is not a key/, fn ->
        defmodule OhneKeys do
          use Shared.Datumsbereich
          defstruct [:anderes_feld]
        end
      end
    end

    test "wirft einen Fehler, wenn ein eigener Key fehlt" do
      assert_raise ArgumentError, ~r/^:gueltig_bis is not a key/, fn ->
        defmodule OhneEigenenKey do
          use Shared.Datumsbereich, beginn: :gueltig_ab, ende: :gueltig_bis
          defstruct [:gueltig_ab]
        end
      end
    end

    test "wirft einen Fehler, wenn der datumsbereich-Key fehlt" do
      assert_raise ArgumentError, ~r/^:fehlt is not a key/, fn ->
        defmodule OhneDatumsbereichKey do
          use Shared.Datumsbereich, datumsbereich: :fehlt
          defstruct [:anderes_feld]
        end
      end
    end
  end

  describe "ueberlagere/1" do
    test "erzeugt keinen leeren Abschnitt, wenn ein Range endet und ein anderer am Folgetag beginnt" do
      monat = Date.range(~D[2025-01-01], ~D[2025-01-10])
      anfang = Date.range(~D[2025-01-01], ~D[2025-01-03])
      mitte = Date.range(~D[2025-01-04], ~D[2025-01-06])

      zeitraeume =
        [monat, anfang, mitte]
        |> Datumsbereich.ueberlagere()
        |> Enum.map(& &1.datumsbereich)

      assert [
               Date.range(~D[2025-01-01], ~D[2025-01-03]),
               Date.range(~D[2025-01-04], ~D[2025-01-06]),
               Date.range(~D[2025-01-07], ~D[2025-01-10])
             ] == zeitraeume
    end

    test "gibt für einen einzelnen Range genau einen Abschnitt zurück" do
      range = Date.range(~D[2025-01-01], ~D[2025-01-05])

      assert [%Ueberlagerung{datumsbereich: ^range, elemente: [^range]}] =
               Datumsbereich.ueberlagere([range])
    end

    test "gibt für eine leere Liste eine leere Liste zurück" do
      assert [] == Datumsbereich.ueberlagere([])
    end
  end
end
