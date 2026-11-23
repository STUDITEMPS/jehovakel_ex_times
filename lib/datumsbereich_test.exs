defmodule Shared.DatumsbereichTest do
  use ExUnit.Case, async: true

  import Shared.Month, only: [sigil_m: 2]
  import Shared.Week, only: [sigil_v: 2]

  alias Shared.Datumsbereich
  alias Shared.Datumsbereich.Ueberlagerung

  doctest Datumsbereich, import: true
  doctest Ueberlagerung, import: true

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

  defmodule EctoSchema do
    use Ecto.Schema
    use Shared.Datumsbereich

    embedded_schema do
      field :beginn, :date
      field :ende, :date, virtual: true
    end
  end

  defmodule Kalender do
    @moduledoc false
    @behaviour Calendar

    Code.ensure_loaded!(Calendar.ISO)

    for {name, stelligkeit} <- Calendar.behaviour_info(:callbacks),
        function_exported?(Calendar.ISO, name, stelligkeit) do
      argumente = Macro.generate_arguments(stelligkeit, __MODULE__)
      @impl Calendar
      def unquote(name)(unquote_splicing(argumente)),
        do: Calendar.ISO.unquote(name)(unquote_splicing(argumente))
    end
  end

  describe "andere Kalender" do
    setup do
      im_kalender = &Date.convert!(&1, Kalender)

      %{
        k: im_kalender,
        basis: Date.range(im_kalender.(~D[2025-01-01]), im_kalender.(~D[2025-01-10]))
      }
    end

    test "differenz/2 liefert Ergebnisse im Kalender der Basis", %{
      k: k,
      basis: basis
    } do
      abzuziehen = [~D[2025-01-03], Date.range(~D[2025-01-06], ~D[2025-01-07])]

      erwartet = [
        Date.range(k.(~D[2025-01-01]), k.(~D[2025-01-02])),
        Date.range(k.(~D[2025-01-04]), k.(~D[2025-01-05])),
        Date.range(k.(~D[2025-01-08]), k.(~D[2025-01-10]))
      ]

      assert erwartet == Datumsbereich.differenz(basis, abzuziehen)

      assert [
               Date.range(k.(~D[2025-01-01]), k.(~D[2025-01-02])),
               Date.range(k.(~D[2025-01-04]), k.(~D[2025-01-10]))
             ] == Datumsbereich.differenz(basis, ~D[2025-01-03])
    end

    test "ueberschneidung/2 liefert das Ergebnis im Kalender des ersten Arguments", %{
      k: k,
      basis: basis
    } do
      assert Date.range(k.(~D[2025-01-05]), k.(~D[2025-01-10])) ==
               Datumsbereich.ueberschneidung(basis, Date.range(~D[2025-01-05], ~D[2025-01-20]))
    end

    test "vereinigung/1 liefert Abschnitte im Kalender ihres ersten Bereichs", %{
      k: k,
      basis: basis
    } do
      assert [Date.range(k.(~D[2025-01-01]), k.(~D[2025-01-15]))] ==
               Datumsbereich.vereinigung([basis, Date.range(~D[2025-01-08], ~D[2025-01-15])])
    end

    test "ueberlagere/1 liefert Abschnitte im Kalender ihres Beginns", %{k: k, basis: basis} do
      assert [
               Date.range(k.(~D[2025-01-01]), k.(~D[2025-01-09])),
               Date.range(~D[2025-01-10], ~D[2025-01-10])
             ] ==
               [basis, ~D[2025-01-10]]
               |> Datumsbereich.ueberlagere()
               |> Enum.map(& &1.datumsbereich)
    end
  end

  describe "Funktionen" do
    test "differenz/2 mit Listen entspricht dem paarweisen Abziehen" do
      :rand.seed(:exsss, {1, 2, 3})

      zufaelliger_bereich = fn ->
        start = Date.add(~D[2025-01-01], :rand.uniform(60))

        if :rand.uniform(3) == 1,
          do: start,
          else: Date.range(start, Date.add(start, :rand.uniform(15) - 1))
      end

      paarweise = fn basis, abzuziehen ->
        Enum.flat_map(basis, fn bereich ->
          Enum.reduce(abzuziehen, [Datumsbereich.to_date_range(bereich)], fn b, teile ->
            Enum.flat_map(teile, &Datumsbereich.differenz(&1, b))
          end)
        end)
      end

      for _ <- 1..500 do
        basis = for _ <- 1..:rand.uniform(5), do: zufaelliger_bereich.()
        abzuziehen = for _ <- 0..:rand.uniform(8), do: zufaelliger_bereich.()

        erwartet = paarweise.(basis, abzuziehen)

        assert erwartet == Datumsbereich.differenz(basis, abzuziehen)
      end
    end

    test "ungültige Date.Ranges führen zu Fehlern statt Endlosschleifen" do
      mit_schrittweite = Date.range(~D[2025-01-01], ~D[2025-01-05], 2)
      leer = Date.range(~D[2025-01-01], ~D[2025-01-05], -1)

      for ungueltig <- [mit_schrittweite, leer] do
        assert_raise ArgumentError, fn ->
          Datumsbereich.ueberschneidung?(ungueltig, ~D[2025-01-01])
        end

        assert_raise ArgumentError, fn -> Datumsbereich.vereinigung([ungueltig]) end
        assert_raise ArgumentError, fn -> Datumsbereich.dauer(ungueltig) end
      end
    end
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

    test "akzeptiert Ecto-Schemas mit (virtuellen) Feldern vom Typ :date" do
      struct = %EctoSchema{beginn: ~D[2025-07-01], ende: ~D[2025-07-14]}

      assert Date.range(~D[2025-07-01], ~D[2025-07-14]) == EctoSchema.to_date_range(struct)
    end

    test "wirft einen Fehler, wenn ein Ecto-Feld nicht vom Typ :date ist" do
      assert_raise ArgumentError,
                   ~r/^:ende of .* must be an Ecto field of type :date, got: :naive_datetime/,
                   fn ->
                     defmodule EctoSchemaMitFalschemTyp do
                       use Ecto.Schema
                       use Shared.Datumsbereich

                       embedded_schema do
                         field :beginn, :date
                         field :ende, :naive_datetime
                       end
                     end
                   end
    end

    test "überspringt die Ecto-Validierung mit ecto_validierung: false" do
      defmodule EctoSchemaOhneValidierung do
        use Ecto.Schema
        use Shared.Datumsbereich, ecto_validierung: false

        embedded_schema do
          field :beginn, :date
          field :ende, :naive_datetime
        end
      end

      assert function_exported?(EctoSchemaOhneValidierung, :to_date_range, 1)
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

  describe "to_date_range/1" do
    test "wirft einen Fehler, wenn ende vor beginn liegt, statt den Bereich umzudrehen" do
      struct = %MitDefaultKeys{beginn: ~D[2025-07-14], ende: ~D[2025-07-01]}

      assert_raise RuntimeError, ~r/Ungültiger Rückgabewert von to_date_range\/1/, fn ->
        Datumsbereich.to_date_range(struct)
      end
    end

    test "macht aus einem Date im datumsbereich-Key einen eintägigen Date.Range" do
      assert Date.range(~D[2025-02-01], ~D[2025-02-01]) ==
               Datumsbereich.to_date_range(%MitDatumsbereichKey{datumsbereich: ~D[2025-02-01]})
    end

    test "ruft to_date_range/1 des Structs im datumsbereich-Key auf" do
      urlaub = %MitDefaultKeys{beginn: ~D[2025-07-01], ende: ~D[2025-07-14]}

      assert Date.range(~D[2025-07-01], ~D[2025-07-14]) ==
               Datumsbereich.to_date_range(%MitDatumsbereichKey{datumsbereich: urlaub})

      assert Date.range(~D[2025-02-01], ~D[2025-03-31]) ==
               Datumsbereich.to_date_range(%MitDatumsbereichKey{
                 datumsbereich: Shared.Month.range(~m[2025-02], ~m[2025-03])
               })
    end

    test "macht aus einem halboffenen Timex.Interval auf Tagesgrenzen einen Date.Range" do
      intervall = %Timex.Interval{from: ~N[2025-01-01 00:00:00], until: ~N[2025-01-02 00:00:00]}

      assert Date.range(~D[2025-01-01], ~D[2025-01-01]) == Datumsbereich.to_date_range(intervall)
    end

    test "wirft einen Fehler für Timex.Intervalle, die nicht genau ganze Tage umfassen" do
      tag = ~N[2025-01-01 00:00:00]
      folgetag = ~N[2025-01-02 00:00:00]

      for intervall <- [
            %Timex.Interval{from: tag, until: tag},
            %Timex.Interval{from: folgetag, until: tag},
            %Timex.Interval{from: ~N[2025-01-01 00:00:00.000001], until: folgetag},
            %Timex.Interval{from: tag, until: folgetag, left_open: true},
            %Timex.Interval{from: tag, until: folgetag, right_open: false},
            %Timex.Interval{from: ~U[2025-01-01 00:00:00Z], until: ~U[2025-01-02 00:00:00Z]}
          ] do
        assert_raise ArgumentError, fn ->
          Datumsbereich.to_date_range(intervall)
        end
      end
    end

    test "wirft einen Fehler, wenn der datumsbereich-Key weder Date.Range noch to_date_range/1 hat" do
      assert_raise ArgumentError, ~r/NaiveDateTime definiert kein to_date_range/, fn ->
        Datumsbereich.to_date_range(%MitDatumsbereichKey{
          datumsbereich: ~N[2025-02-01 00:00:00]
        })
      end
    end
  end
end
