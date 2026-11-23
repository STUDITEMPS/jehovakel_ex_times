if Code.ensure_loaded?(Ecto.Query) do
  defmodule Shared.Datumsbereich.Query do
    @moduledoc """
    Ecto-Queries für Entities mit einem Datumsbereich aus Beginn- und Ende-Feld:
    `ueberschneidet_sich_mit/3`, `beginnt_in/3`, `endet_in/3`, `enthaelt/3`,
    `ist_enthalten_in/3` und `entspricht/3`.

    Zu jeder Funktion gibt es eine Negation, z. B. `ueberschneidet_sich_nicht_mit/3`.
    Sie liefert genau die Entities, die die ursprüngliche Funktion nicht liefert,
    auch wenn das Ende-Feld `NULL` ist. Ein leeres Beginn-Feld wird nicht
    unterstützt.

    Nur verfügbar, wenn `:ecto` als Dependency eingebunden ist.

    ## Beispiele

    Mit einem Schema, das `use Shared.Datumsbereich` mit Beginn- und Ende-Key
    verwendet, werden die Felder automatisch ermittelt:

        defmodule Vertrag do
          use Ecto.Schema
          use Shared.Datumsbereich, beginn: :gueltig_ab, ende: :gueltig_bis

          schema "vertraege" do
            field :gueltig_ab, :date
            field :gueltig_bis, :date
          end
        end

        Vertrag
        |> Shared.Datumsbereich.Query.ueberschneidet_sich_mit(~m[2025-01])
        |> Repo.all()

    Mit expliziten Feldern und Beginn & Ende des Datumsbereichs:

        "vertraege"
        |> Shared.Datumsbereich.Query.ueberschneidet_sich_mit(
          [beginn: ~D[2025-01-01], ende: ~D[2025-01-31]],
          felder: [beginn: :gueltig_ab, ende: :gueltig_bis]
        )
        |> select([v], v.id)
        |> Repo.all()

    Mit einem benannten Binding aus einem Join, hier von einem `Urlaub` mit
    `belongs_to :vertrag, Vertrag` auf seinen Vertrag:

        Urlaub
        |> join(:inner, [u], v in assoc(u, :vertrag), as: :vertrag)
        |> Shared.Datumsbereich.Query.ueberschneidet_sich_mit(~m[2025-01], binding: :vertrag)
        |> Repo.all()
    """

    alias Shared.Datumsbereich

    import Ecto.Query, only: [dynamic: 1, dynamic: 2, where: 2]

    @typedoc """
    * `:felder` – Beginn- und Ende-Feld der Entity, z. B.
      `[beginn: :von, ende: :bis]`. Ohne diese Option werden die Felder aus dem
      Schema des Bindings gelesen, das dafür `use Shared.Datumsbereich` mit
      `:beginn` und `:ende` verwenden muss.
    * `:binding` – Name eines benannten Bindings (`as:`), auf das sich die Felder
      beziehen. Default ist das `from` der Query.
    """
    @type opts :: [felder: [beginn: atom(), ende: atom()], binding: atom()]

    @typedoc """
    Wie `t:opts/0`, zusätzlich:

    * `:offenes_ende` – Mit `true` gilt ein Ende-Feld mit `NULL` als offenes
      Ende, die Entity reicht also unbegrenzt in die Zukunft. Default ist
      `false`, dann trifft die Bedingung auf solche Entities nie zu.
    """
    @type opts_mit_offenem_ende :: [
            felder: [beginn: atom(), ende: atom()],
            binding: atom(),
            offenes_ende: boolean()
          ]

    @doc """
    Schränkt `query` auf Entities ein, die sich mit `datumsbereich` überschneiden,
    also mindestens einen gemeinsamen Tag haben.

    Optionen siehe `t:opts_mit_offenem_ende/0`.

    ## Beispiele

        iex> ueberschneidet_sich_mit(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab <= ^~D[2025-01-31] and v0.gueltig_bis >= ^~D[2025-01-01]>

        iex> ueberschneidet_sich_mit(Vertrag, ~m[2025-01], offenes_ende: true)
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab <= ^~D[2025-01-31] and (is_nil(v0.gueltig_bis) or v0.gueltig_bis >= ^~D[2025-01-01])>

        iex> ueberschneidet_sich_mit(
        ...>   "vertraege",
        ...>   [beginn: ~D[2025-01-01], ende: ~D[2025-01-15]],
        ...>   felder: [beginn: :anfang, ende: :schluss]
        ...> )
        #Ecto.Query<from v0 in "vertraege", where: v0.anfang <= ^~D[2025-01-15] and v0.schluss >= ^~D[2025-01-01]>
    """
    @spec ueberschneidet_sich_mit(Ecto.Queryable.t(), Datumsbereich.t(), opts_mit_offenem_ende()) ::
            Ecto.Query.t()
    def ueberschneidet_sich_mit(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts, offenes_ende: false)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^spaetestens(binding, beginn_feld, letzter_tag) and
            ^ende_fruehestens(binding, ende_feld, erster_tag, opts[:offenes_ende])
        )

      where(query, ^bedingung)
    end

    @doc """
    Negation von `ueberschneidet_sich_mit/3`: Schränkt `query` auf Entities ein,
    die keinen Tag mit `datumsbereich` gemeinsam haben.

    Optionen siehe `t:opts_mit_offenem_ende/0`. Ohne `offenes_ende: true`
    überschneiden sich Entities ohne Ende mit nichts und sind daher enthalten.

    ## Beispiele

        iex> ueberschneidet_sich_nicht_mit(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab > ^~D[2025-01-31] or (is_nil(v0.gueltig_bis) or v0.gueltig_bis < ^~D[2025-01-01])>

        iex> ueberschneidet_sich_nicht_mit(Vertrag, ~m[2025-01], offenes_ende: true)
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab > ^~D[2025-01-31] or v0.gueltig_bis < ^~D[2025-01-01]>
    """
    @spec ueberschneidet_sich_nicht_mit(
            Ecto.Queryable.t(),
            Datumsbereich.t(),
            opts_mit_offenem_ende()
          ) :: Ecto.Query.t()
    def ueberschneidet_sich_nicht_mit(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts, offenes_ende: false)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^spaeter_als(binding, beginn_feld, letzter_tag) or
            ^ende_frueher_als(binding, ende_feld, erster_tag, opts[:offenes_ende])
        )

      where(query, ^bedingung)
    end

    @doc """
    Schränkt `query` auf Entities ein, deren erster Tag in `datumsbereich` liegt.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> beginnt_in(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab >= ^~D[2025-01-01] and v0.gueltig_ab <= ^~D[2025-01-31]>

        iex> beginnt_in(Vertrag, ~D[2025-01-15])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab >= ^~D[2025-01-15] and v0.gueltig_ab <= ^~D[2025-01-15]>
    """
    @spec beginnt_in(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def beginnt_in(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, _ende_feld}, tage} = vorbereiten!(query, datumsbereich, opts)
      where(query, ^zwischen(opts[:binding], beginn_feld, tage))
    end

    @doc """
    Negation von `beginnt_in/3`: Schränkt `query` auf Entities ein, deren erster
    Tag nicht in `datumsbereich` liegt.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> beginnt_nicht_in(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab < ^~D[2025-01-01] or v0.gueltig_ab > ^~D[2025-01-31]>
    """
    @spec beginnt_nicht_in(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def beginnt_nicht_in(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, _ende_feld}, tage} = vorbereiten!(query, datumsbereich, opts)
      where(query, ^ausserhalb(opts[:binding], beginn_feld, tage))
    end

    @doc """
    Schränkt `query` auf Entities ein, deren letzter Tag in `datumsbereich` liegt.
    Entities ohne Ende liegen nie darin.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> endet_in(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_bis >= ^~D[2025-01-01] and v0.gueltig_bis <= ^~D[2025-01-31]>

    Mit den Feldern aus dem Schema eines Joins:

        iex> Urlaub
        ...> |> join(:inner, [u], v in assoc(u, :vertrag), as: :vertrag)
        ...> |> endet_in(~m[2025-01], binding: :vertrag)
        #Ecto.Query<from u0 in Urlaub, join: v1 in assoc(u0, :vertrag), as: :vertrag, where: v1.gueltig_bis >= ^~D[2025-01-01] and v1.gueltig_bis <= ^~D[2025-01-31]>
    """
    @spec endet_in(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def endet_in(query, datumsbereich, opts \\ []) do
      {query, opts, {_beginn_feld, ende_feld}, tage} = vorbereiten!(query, datumsbereich, opts)
      where(query, ^zwischen(opts[:binding], ende_feld, tage))
    end

    @doc """
    Negation von `endet_in/3`: Schränkt `query` auf Entities ein, deren letzter
    Tag nicht in `datumsbereich` liegt. Entities ohne Ende sind immer enthalten.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> endet_nicht_in(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: is_nil(v0.gueltig_bis) or (v0.gueltig_bis < ^~D[2025-01-01] or v0.gueltig_bis > ^~D[2025-01-31])>
    """
    @spec endet_nicht_in(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def endet_nicht_in(query, datumsbereich, opts \\ []) do
      {query, opts, {_beginn_feld, ende_feld}, tage} = vorbereiten!(query, datumsbereich, opts)
      binding = opts[:binding]

      where(
        query,
        ^dynamic(^ohne_wert(binding, ende_feld) or ^ausserhalb(binding, ende_feld, tage))
      )
    end

    @doc """
    Schränkt `query` auf Entities ein, die alle Tage von `datumsbereich` enthalten.
    Pendant zu `ist_enthalten_in/3`.

    Optionen siehe `t:opts_mit_offenem_ende/0`.

    ## Beispiele

        iex> enthaelt(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab <= ^~D[2025-01-01] and v0.gueltig_bis >= ^~D[2025-01-31]>

        iex> enthaelt(Vertrag, ~m[2025-01], offenes_ende: true)
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab <= ^~D[2025-01-01] and (is_nil(v0.gueltig_bis) or v0.gueltig_bis >= ^~D[2025-01-31])>
    """
    @spec enthaelt(Ecto.Queryable.t(), Datumsbereich.t(), opts_mit_offenem_ende()) ::
            Ecto.Query.t()
    def enthaelt(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts, offenes_ende: false)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^spaetestens(binding, beginn_feld, erster_tag) and
            ^ende_fruehestens(binding, ende_feld, letzter_tag, opts[:offenes_ende])
        )

      where(query, ^bedingung)
    end

    @doc """
    Negation von `enthaelt/3`: Schränkt `query` auf Entities ein, denen mindestens
    ein Tag von `datumsbereich` fehlt.

    Optionen siehe `t:opts_mit_offenem_ende/0`. Ohne `offenes_ende: true`
    enthalten Entities ohne Ende nichts und sind daher enthalten.

    ## Beispiele

        iex> enthaelt_nicht(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab > ^~D[2025-01-01] or (is_nil(v0.gueltig_bis) or v0.gueltig_bis < ^~D[2025-01-31])>

        iex> enthaelt_nicht(Vertrag, ~m[2025-01], offenes_ende: true)
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab > ^~D[2025-01-01] or v0.gueltig_bis < ^~D[2025-01-31]>
    """
    @spec enthaelt_nicht(Ecto.Queryable.t(), Datumsbereich.t(), opts_mit_offenem_ende()) ::
            Ecto.Query.t()
    def enthaelt_nicht(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts, offenes_ende: false)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^spaeter_als(binding, beginn_feld, erster_tag) or
            ^ende_frueher_als(binding, ende_feld, letzter_tag, opts[:offenes_ende])
        )

      where(query, ^bedingung)
    end

    @doc """
    Schränkt `query` auf Entities ein, deren Tage alle in `datumsbereich` liegen.
    Pendant zu `enthaelt/3`. Entities ohne Ende liegen nie darin.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> ist_enthalten_in(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab >= ^~D[2025-01-01] and v0.gueltig_bis <= ^~D[2025-01-31]>
    """
    @spec ist_enthalten_in(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def ist_enthalten_in(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^fruehestens(binding, beginn_feld, erster_tag) and
            ^spaetestens(binding, ende_feld, letzter_tag)
        )

      where(query, ^bedingung)
    end

    @doc """
    Negation von `ist_enthalten_in/3`: Schränkt `query` auf Entities ein, von
    denen mindestens ein Tag außerhalb von `datumsbereich` liegt. Entities ohne
    Ende sind immer enthalten.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> ist_nicht_enthalten_in(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab < ^~D[2025-01-01] or is_nil(v0.gueltig_bis) or v0.gueltig_bis > ^~D[2025-01-31]>
    """
    @spec ist_nicht_enthalten_in(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def ist_nicht_enthalten_in(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^frueher_als(binding, beginn_feld, erster_tag) or ^ohne_wert(binding, ende_feld) or
            ^spaeter_als(binding, ende_feld, letzter_tag)
        )

      where(query, ^bedingung)
    end

    @doc """
    Schränkt `query` auf Entities ein, die genau an den Tagen von `datumsbereich`
    beginnen und enden. Entities ohne Ende entsprechen ihm nie.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> entspricht(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab == ^~D[2025-01-01] and v0.gueltig_bis == ^~D[2025-01-31]>
    """
    @spec entspricht(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def entspricht(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^gleich(binding, beginn_feld, erster_tag) and ^gleich(binding, ende_feld, letzter_tag)
        )

      where(query, ^bedingung)
    end

    @doc """
    Negation von `entspricht/3`: Schränkt `query` auf Entities ein, die an einem
    anderen Tag als `datumsbereich` beginnen oder enden. Entities ohne Ende sind
    immer enthalten.

    Optionen siehe `t:opts/0`.

    ## Beispiele

        iex> entspricht_nicht(Vertrag, ~m[2025-01])
        #Ecto.Query<from v0 in Vertrag, where: v0.gueltig_ab != ^~D[2025-01-01] or is_nil(v0.gueltig_bis) or v0.gueltig_bis != ^~D[2025-01-31]>
    """
    @spec entspricht_nicht(Ecto.Queryable.t(), Datumsbereich.t(), opts()) :: Ecto.Query.t()
    def entspricht_nicht(query, datumsbereich, opts \\ []) do
      {query, opts, {beginn_feld, ende_feld}, {erster_tag, letzter_tag}} =
        vorbereiten!(query, datumsbereich, opts)

      binding = opts[:binding]

      bedingung =
        dynamic(
          ^ungleich(binding, beginn_feld, erster_tag) or ^ohne_wert(binding, ende_feld) or
            ^ungleich(binding, ende_feld, letzter_tag)
        )

      where(query, ^bedingung)
    end

    defp vorbereiten!(query, datumsbereich, opts, weitere_opts \\ []) do
      query = Ecto.Queryable.to_query(query)
      opts = Keyword.validate!(opts, [:felder, :binding | weitere_opts])
      %{first: erster_tag, last: letzter_tag} = Datumsbereich.to_date_range(datumsbereich)
      {query, opts, felder!(query, opts), {erster_tag, letzter_tag}}
    end

    defp zwischen(binding, feld, {erster_tag, letzter_tag}) do
      dynamic(
        ^fruehestens(binding, feld, erster_tag) and ^spaetestens(binding, feld, letzter_tag)
      )
    end

    defp ausserhalb(binding, feld, {erster_tag, letzter_tag}) do
      dynamic(^frueher_als(binding, feld, erster_tag) or ^spaeter_als(binding, feld, letzter_tag))
    end

    defp ende_frueher_als(binding, ende_feld, tag, true), do: frueher_als(binding, ende_feld, tag)

    defp ende_frueher_als(binding, ende_feld, tag, false),
      do: dynamic(^ohne_wert(binding, ende_feld) or ^frueher_als(binding, ende_feld, tag))

    defp ende_fruehestens(binding, ende_feld, tag, true),
      do: dynamic(^ohne_wert(binding, ende_feld) or ^fruehestens(binding, ende_feld, tag))

    defp ende_fruehestens(binding, ende_feld, tag, false),
      do: fruehestens(binding, ende_feld, tag)

    # Vergleiche direkt am Feld, damit Ecto die Dates über den Feldtyp castet.
    defp spaetestens(nil, feld, tag), do: dynamic([entity], field(entity, ^feld) <= ^tag)

    defp spaetestens(binding, feld, tag),
      do: dynamic([{^binding, entity}], field(entity, ^feld) <= ^tag)

    defp fruehestens(nil, feld, tag), do: dynamic([entity], field(entity, ^feld) >= ^tag)

    defp fruehestens(binding, feld, tag),
      do: dynamic([{^binding, entity}], field(entity, ^feld) >= ^tag)

    defp frueher_als(nil, feld, tag), do: dynamic([entity], field(entity, ^feld) < ^tag)

    defp frueher_als(binding, feld, tag),
      do: dynamic([{^binding, entity}], field(entity, ^feld) < ^tag)

    defp spaeter_als(nil, feld, tag), do: dynamic([entity], field(entity, ^feld) > ^tag)

    defp spaeter_als(binding, feld, tag),
      do: dynamic([{^binding, entity}], field(entity, ^feld) > ^tag)

    defp gleich(nil, feld, tag), do: dynamic([entity], field(entity, ^feld) == ^tag)

    defp gleich(binding, feld, tag),
      do: dynamic([{^binding, entity}], field(entity, ^feld) == ^tag)

    defp ungleich(nil, feld, tag), do: dynamic([entity], field(entity, ^feld) != ^tag)

    defp ungleich(binding, feld, tag),
      do: dynamic([{^binding, entity}], field(entity, ^feld) != ^tag)

    defp ohne_wert(nil, feld), do: dynamic([entity], is_nil(field(entity, ^feld)))
    defp ohne_wert(binding, feld), do: dynamic([{^binding, entity}], is_nil(field(entity, ^feld)))

    defp felder!(query, opts) do
      case opts[:felder] do
        nil -> felder_aus_binding!(query, opts[:binding])
        felder -> explizite_felder!(felder)
      end
    end

    defp felder_aus_binding!(query, binding),
      do: query |> schema_des_bindings!(binding) |> datumsbereich_felder!()

    defp explizite_felder!(felder) do
      with :error <- beginn_und_ende(felder) do
        raise ArgumentError,
              ":felder must be a keyword list with exactly :beginn and :ende, got: #{inspect(felder)}"
      end
    end

    defp beginn_und_ende(beginn: beginn, ende: ende), do: {beginn, ende}
    defp beginn_und_ende(ende: ende, beginn: beginn), do: {beginn, ende}
    defp beginn_und_ende(_), do: :error

    defp schema_des_bindings!(query, nil), do: schema_an_index!(query, 0)

    defp schema_des_bindings!(query, binding) do
      case query.aliases do
        %{^binding => index} -> schema_an_index!(query, index)
        _ -> raise ArgumentError, "unknown binding #{inspect(binding)} in #{inspect(query)}"
      end
    end

    defp schema_an_index!(query, 0), do: schema_aus_quelle!(query.from.source, query)

    defp schema_an_index!(query, index) do
      case Enum.at(query.joins, index - 1) do
        %{assoc: {eltern_index, assoziation}} ->
          eltern_schema = schema_an_index!(query, eltern_index)
          eltern_schema.__schema__(:association, assoziation).related

        %{source: quelle} ->
          schema_aus_quelle!(quelle, query)
      end
    end

    defp schema_aus_quelle!({_tabelle, schema}, _query) when is_atom(schema) and schema != nil,
      do: schema

    defp schema_aus_quelle!(_quelle, query) do
      raise ArgumentError,
            "cannot determine Datumsbereich fields without an Ecto schema in #{inspect(query)}. " <>
              "Pass the fields explicitly with the :felder option"
    end

    defp datumsbereich_felder!(schema) do
      if Code.ensure_loaded?(schema) and function_exported?(schema, :__datumsbereich_felder__, 0) do
        schema.__datumsbereich_felder__()
      else
        raise ArgumentError,
              "#{inspect(schema)} does not use Shared.Datumsbereich with :beginn and :ende keys. " <>
                "Pass the fields explicitly with the :felder option"
      end
    end
  end
end
