defmodule Shared.Datumsbereich.QueryTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import Shared.Month, only: [sigil_m: 2]

  alias Shared.Datumsbereich.Query

  doctest Query, import: true

  defmodule OhneDatumsbereich do
    use Ecto.Schema

    schema "ohne_datumsbereich" do
      field :von, :date
      field :bis, :date
    end
  end

  defmodule MitDatumsbereichKey do
    use Ecto.Schema
    use Shared.Datumsbereich, datumsbereich: :tag

    schema "mit_datumsbereich_key" do
      field :tag, :date
    end
  end

  describe "ueberschneidet_sich_mit/3 mit Feldern aus dem Schema" do
    test "ermittelt Beginn & Ende aus dem Datumsbereich" do
      erwartet =
        where(Vertrag, [v], v.gueltig_ab <= ^~D[2025-01-31] and v.gueltig_bis >= ^~D[2025-01-01])

      assert_gleiche_query(erwartet, Query.ueberschneidet_sich_mit(Vertrag, ~m[2025-01]))
    end

    test "akzeptiert eine Query mit Schema im from" do
      query = from(v in Vertrag, where: v.id > 0)

      erwartet =
        where(query, [v], v.gueltig_ab <= ^~D[2025-01-05] and v.gueltig_bis >= ^~D[2025-01-05])

      assert_gleiche_query(erwartet, Query.ueberschneidet_sich_mit(query, ~D[2025-01-05]))
    end

    test "akzeptiert Beginn & Ende als Keyword-Liste" do
      erwartet =
        where(Vertrag, [v], v.gueltig_ab <= ^~D[2025-02-10] and v.gueltig_bis >= ^~D[2025-02-01])

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(Vertrag, beginn: ~D[2025-02-01], ende: ~D[2025-02-10])
      )
    end

    test "behandelt NULL im Ende-Feld mit offenes_ende: true als offenes Ende" do
      erwartet =
        where(
          Vertrag,
          [v],
          v.gueltig_ab <= ^~D[2025-01-31] and
            (is_nil(v.gueltig_bis) or v.gueltig_bis >= ^~D[2025-01-01])
        )

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(Vertrag, ~m[2025-01], offenes_ende: true)
      )
    end

    test "wirft einen Fehler, wenn das Schema keine Datumsbereich-Felder markiert" do
      assert_raise ArgumentError, ~r/does not use Shared.Datumsbereich/, fn ->
        Query.ueberschneidet_sich_mit(OhneDatumsbereich, ~m[2025-01])
      end

      assert_raise ArgumentError, ~r/does not use Shared.Datumsbereich/, fn ->
        Query.ueberschneidet_sich_mit(MitDatumsbereichKey, ~m[2025-01])
      end
    end

    test "wirft einen Fehler ohne Schema im from" do
      assert_raise ArgumentError, ~r/without an Ecto schema/, fn ->
        Query.ueberschneidet_sich_mit("vertraege", ~m[2025-01])
      end
    end
  end

  describe "ueberschneidet_sich_mit/3 mit :felder" do
    test "verwendet die angegebenen Felder" do
      erwartet =
        where("vertraege", [v], v.anfang <= ^~D[2025-02-10] and v.schluss >= ^~D[2025-02-01])

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(
          "vertraege",
          [beginn: ~D[2025-02-01], ende: ~D[2025-02-10]],
          felder: [beginn: :anfang, ende: :schluss]
        )
      )
    end

    test "hat Vorrang vor den Feldern aus dem Schema" do
      erwartet =
        where(Vertrag, [v], v.anfang <= ^~D[2025-02-28] and v.gueltig_bis >= ^~D[2025-02-01])

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(Vertrag, ~m[2025-02],
          felder: [ende: :gueltig_bis, beginn: :anfang]
        )
      )
    end

    test "wirft einen Fehler bei unvollständigen Feldern" do
      assert_raise ArgumentError, ~r/^:felder must be a keyword list/, fn ->
        Query.ueberschneidet_sich_mit(Vertrag, ~m[2025-02], felder: [beginn: :von])
      end
    end
  end

  describe "ueberschneidet_sich_mit/3 mit :binding" do
    test "verwendet ein benanntes Binding aus dem from" do
      query = from(v in Vertrag, as: :vertrag)

      erwartet =
        where(
          query,
          [vertrag: v],
          v.gueltig_ab <= ^~D[2025-01-31] and v.gueltig_bis >= ^~D[2025-01-01]
        )

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(query, ~m[2025-01], binding: :vertrag)
      )
    end

    test "ermittelt die Felder aus dem Schema eines Joins" do
      query = join(Urlaub, :inner, [u], v in Vertrag, as: :vertrag, on: v.id == u.vertrag_id)

      erwartet =
        where(
          query,
          [vertrag: v],
          v.gueltig_ab <= ^~D[2025-01-31] and
            (is_nil(v.gueltig_bis) or v.gueltig_bis >= ^~D[2025-01-01])
        )

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(query, ~m[2025-01], binding: :vertrag, offenes_ende: true)
      )
    end

    test "ermittelt die Felder aus dem Schema eines assoc-Joins" do
      query = join(Urlaub, :inner, [u], v in assoc(u, :vertrag), as: :vertrag)

      erwartet =
        where(
          query,
          [vertrag: v],
          v.gueltig_ab <= ^~D[2025-01-31] and v.gueltig_bis >= ^~D[2025-01-01]
        )

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(query, ~m[2025-01], binding: :vertrag)
      )
    end

    test "verwendet :felder für ein Binding ohne Schema" do
      query = join("urlaube", :inner, [u], v in "vertraege", as: :vertrag, on: true)

      erwartet =
        where(query, [vertrag: v], v.ab <= ^~D[2025-01-31] and v.bis >= ^~D[2025-01-01])

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_mit(query, ~m[2025-01],
          binding: :vertrag,
          felder: [beginn: :ab, ende: :bis]
        )
      )
    end

    test "wirft einen Fehler bei einem unbekannten Binding" do
      assert_raise ArgumentError, ~r/^unknown binding :fehlt/, fn ->
        Query.ueberschneidet_sich_mit(Vertrag, ~m[2025-01], binding: :fehlt)
      end
    end
  end

  describe "beginnt_in/3" do
    test "prüft, ob das Beginn-Feld im Datumsbereich liegt" do
      erwartet =
        where(Vertrag, [v], v.gueltig_ab >= ^~D[2025-01-01] and v.gueltig_ab <= ^~D[2025-01-31])

      assert_gleiche_query(erwartet, Query.beginnt_in(Vertrag, ~m[2025-01]))
    end

    test "unterstützt :felder und :binding" do
      query = from(v in "vertraege", as: :vertrag)

      erwartet =
        where(query, [vertrag: v], v.ab >= ^~D[2025-01-01] and v.ab <= ^~D[2025-01-31])

      assert_gleiche_query(
        erwartet,
        Query.beginnt_in(query, ~m[2025-01], binding: :vertrag, felder: [beginn: :ab, ende: :bis])
      )
    end

    test "unterstützt kein :offenes_ende" do
      assert_raise ArgumentError, fn ->
        Query.beginnt_in(Vertrag, ~m[2025-01], offenes_ende: true)
      end
    end
  end

  describe "endet_in/3" do
    test "prüft, ob das Ende-Feld im Datumsbereich liegt" do
      erwartet =
        where(Vertrag, [v], v.gueltig_bis >= ^~D[2025-01-01] and v.gueltig_bis <= ^~D[2025-01-31])

      assert_gleiche_query(erwartet, Query.endet_in(Vertrag, ~m[2025-01]))
    end

    test "ermittelt die Felder aus dem Schema eines Bindings" do
      query = join(Urlaub, :inner, [u], v in assoc(u, :vertrag), as: :vertrag)

      erwartet =
        where(
          query,
          [vertrag: v],
          v.gueltig_bis >= ^~D[2025-01-01] and v.gueltig_bis <= ^~D[2025-01-31]
        )

      assert_gleiche_query(erwartet, Query.endet_in(query, ~m[2025-01], binding: :vertrag))
    end

    test "unterstützt kein :offenes_ende" do
      assert_raise ArgumentError, fn ->
        Query.endet_in(Vertrag, ~m[2025-01], offenes_ende: true)
      end
    end
  end

  describe "enthaelt/3" do
    test "prüft, ob die Entity alle Tage des Datumsbereichs enthält" do
      erwartet =
        where(Vertrag, [v], v.gueltig_ab <= ^~D[2025-01-01] and v.gueltig_bis >= ^~D[2025-01-31])

      assert_gleiche_query(erwartet, Query.enthaelt(Vertrag, ~m[2025-01]))
    end

    test "behandelt NULL im Ende-Feld mit offenes_ende: true als offenes Ende" do
      erwartet =
        where(
          Vertrag,
          [v],
          v.gueltig_ab <= ^~D[2025-01-01] and
            (is_nil(v.gueltig_bis) or v.gueltig_bis >= ^~D[2025-01-31])
        )

      assert_gleiche_query(erwartet, Query.enthaelt(Vertrag, ~m[2025-01], offenes_ende: true))
    end

    test "unterstützt :felder und :binding" do
      query = join(Urlaub, :inner, [u], v in "vertraege", as: :vertrag, on: true)

      erwartet =
        where(query, [vertrag: v], v.ab <= ^~D[2025-01-05] and v.bis >= ^~D[2025-01-05])

      assert_gleiche_query(
        erwartet,
        Query.enthaelt(query, ~D[2025-01-05],
          binding: :vertrag,
          felder: [beginn: :ab, ende: :bis]
        )
      )
    end
  end

  describe "ist_enthalten_in/3" do
    test "prüft, ob alle Tage der Entity im Datumsbereich liegen" do
      erwartet =
        where(Vertrag, [v], v.gueltig_ab >= ^~D[2025-01-01] and v.gueltig_bis <= ^~D[2025-01-31])

      assert_gleiche_query(erwartet, Query.ist_enthalten_in(Vertrag, ~m[2025-01]))
    end

    test "unterstützt :felder und :binding" do
      query = join(Urlaub, :inner, [u], v in "vertraege", as: :vertrag, on: true)

      erwartet =
        where(query, [vertrag: v], v.ab >= ^~D[2025-01-01] and v.bis <= ^~D[2025-12-31])

      assert_gleiche_query(
        erwartet,
        Query.ist_enthalten_in(query, [beginn: ~D[2025-01-01], ende: ~D[2025-12-31]],
          binding: :vertrag,
          felder: [beginn: :ab, ende: :bis]
        )
      )
    end

    test "unterstützt kein :offenes_ende" do
      assert_raise ArgumentError, fn ->
        Query.ist_enthalten_in(Vertrag, ~m[2025-01], offenes_ende: true)
      end
    end
  end

  describe "negierte Varianten" do
    test "verwenden :binding und die Felder aus dem Schema des Bindings" do
      query = join(Urlaub, :inner, [u], v in assoc(u, :vertrag), as: :vertrag)

      erwartet =
        where(
          query,
          [vertrag: v],
          v.gueltig_ab > ^~D[2025-01-31] or v.gueltig_bis < ^~D[2025-01-01]
        )

      assert_gleiche_query(
        erwartet,
        Query.ueberschneidet_sich_nicht_mit(query, ~m[2025-01],
          binding: :vertrag,
          offenes_ende: true
        )
      )
    end

    test "verwenden :felder" do
      erwartet =
        where(
          "vertraege",
          [v],
          v.ab < ^~D[2025-01-01] or is_nil(v.bis) or v.bis > ^~D[2025-01-31]
        )

      assert_gleiche_query(
        erwartet,
        Query.ist_nicht_enthalten_in("vertraege", ~m[2025-01], felder: [beginn: :ab, ende: :bis])
      )
    end

    test "unterstützen :offenes_ende nur, wenn die positive Variante es unterstützt" do
      for funktion <- [:beginnt_nicht_in, :endet_nicht_in, :ist_nicht_enthalten_in] do
        assert_raise ArgumentError, fn ->
          apply(Query, funktion, [Vertrag, ~m[2025-01], [offenes_ende: true]])
        end
      end
    end
  end

  test "wirft einen Fehler bei unbekannten Optionen" do
    assert_raise ArgumentError, fn ->
      Query.ueberschneidet_sich_mit(Vertrag, ~m[2025-01], unbekannt: true)
    end
  end

  test "wirft einen Fehler, wenn Beginn & Ende keine Dates sind" do
    assert_raise ArgumentError, ~r/^datumsbereich must be a keyword list with Dates/, fn ->
      Query.ueberschneidet_sich_mit(Vertrag,
        beginn: ~N[2025-01-01 00:00:00],
        ende: ~D[2025-01-31]
      )
    end
  end

  test "wirft einen Fehler, wenn Beginn nach Ende liegt" do
    assert_raise ArgumentError, ~r/^datumsbereich :beginn must not be after :ende/, fn ->
      Query.ueberschneidet_sich_mit(Vertrag, beginn: ~D[2025-01-31], ende: ~D[2025-01-01])
    end
  end

  test "akzeptiert Beginn gleich Ende" do
    erwartet =
      where(
        Vertrag,
        [v],
        v.gueltig_ab <= ^~D[2025-01-15] and v.gueltig_bis >= ^~D[2025-01-15]
      )

    assert_gleiche_query(
      erwartet,
      Query.ueberschneidet_sich_mit(Vertrag, beginn: ~D[2025-01-15], ende: ~D[2025-01-15])
    )
  end

  # inspect/1 zeigt nicht, gegen welchen Typ Ecto die Parameter castet.
  defp assert_gleiche_query(erwartet, tatsaechlich) do
    assert inspect(erwartet) == inspect(tatsaechlich)
    assert where_ausdruecke(erwartet) == where_ausdruecke(tatsaechlich)
  end

  defp where_ausdruecke(query), do: Enum.map(query.wheres, &{&1.expr, &1.params})
end
