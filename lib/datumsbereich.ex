defmodule Shared.Datumsbereich do
  @moduledoc """
  Funktionen für ganztägige Zeiträume auf Basis von `t:Date.Range.t/0`.

  Gerechnet wird direkt auf den ISO-Tagen der Ranges. Alle Funktionen wandeln
  ihre Argumente mit `to_date_range/1` in nicht leere, aufsteigende Ranges mit
  `step: 1` um. Absteigende Ranges mit `step: -1` werden dabei umgedreht.

  ## Beispiele

      iex> ueberschneidung?(
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-05]),
      ...>   Date.range(~D[2025-01-05], ~D[2025-01-10])
      ...> )
      true

      iex> differenz(
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-10]),
      ...>   Date.range(~D[2025-01-04], ~D[2025-01-06])
      ...> )
      [Date.range(~D[2025-01-01], ~D[2025-01-03]), Date.range(~D[2025-01-07], ~D[2025-01-10])]

      iex> vereinigung([
      ...>   Date.range(~D[2025-01-06], ~D[2025-01-10]),
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-05])
      ...> ])
      [Date.range(~D[2025-01-01], ~D[2025-01-10])]

  ## Eigene Structs als Datumsbereich

  Ein Struct-Modul wird zum Datumsbereich, indem es `c:to_date_range/1`
  implementiert, direkt oder mit `use Shared.Datumsbereich`, siehe `__using__/1`.
  `Shared.Month`, `Shared.Week` und ihre Ranges tun das bereits.
  `to_date_range/1` wandelt solche Structs in ein `Date.Range` um:

      iex> to_date_range(Shared.Month.range(~m[2025-01], ~m[2025-02]))
      Date.range(~D[2025-01-01], ~D[2025-02-28])
  """

  alias Shared.Datumsbereich.Ueberlagerung

  @typedoc """
  Ein `t:Date.Range.t/0` mit `step: 1` oder `-1`, ein `t:Date.t/0` oder ein
  Struct, dessen Modul `c:to_date_range/1` implementiert.
  """
  @type t ::
          %Date.Range{
            first: Date.t(),
            first_in_iso_days: integer,
            last: Date.t(),
            last_in_iso_days: integer,
            step: 1 | -1
          }
          | Date.t()
          | struct()

  @doc """
  Gibt den Datumsbereich `t:t/0` eines Structs zurück.

  Diesen Callback implementieren Module von Structs, die einen Zeitraum
  beschreiben, zum Beispiel eine Woche (`Shared.Week`) oder Schulferien.

  Zurückgegeben wird ein nicht leeres `Date.Range` mit `step: 1` oder `-1`, ein
  `Date` oder ein Struct, das sich wiederum in ein `Date.Range` umwandeln lässt.
  Die Funktionen dieses Moduls rufen den Callback über `to_date_range/1` auf.
  """
  @callback to_date_range(struct()) :: t()

  defmacrop beginn(range), do: quote(do: unquote(range).first_in_iso_days)
  defmacrop ende(range), do: quote(do: unquote(range).last_in_iso_days)

  defguardp is_valid(range)
            when is_struct(range, Date.Range) and range.step == 1 and beginn(range) <= ende(range)

  defguardp are_valid(a, b) when is_valid(a) and is_valid(b)

  # Nur private, da a & b sortiert sein müssen.
  defguardp luecke_besteht(a, b) when ende(a) + 1 < beginn(b)

  @doc """
  Implementiert `c:to_date_range/1` im aufrufenden Struct-Modul.

  Die Keys werden zur Compile-Zeit gegen die Felder des Structs geprüft. Das
  generierte `to_date_range/1` normalisiert nicht, dafür ist
  `Shared.Datumsbereich.to_date_range/1` zuständig.

  ## Optionen

    * `:datumsbereich` – Feld mit einem `Date`, einem `Date.Range` oder einem
      Struct, dessen Modul selbst `to_date_range/1` implementiert.
    * `:beginn` – Feld mit dem ersten Tag als `Date`. Default ist `:beginn`,
      bzw. `:start`, wenn das Struct kein Feld `:beginn`, aber ein Feld `:start` hat.
    * `:ende` – Feld mit dem letzten Tag (inklusive) als `Date`. Default ist `:ende`.

  ## Beispiele

  Mit den Default-Keys:

      defmodule Urlaub do
        use Shared.Datumsbereich
        defstruct [:beginn, :ende]
      end

      Urlaub.to_date_range(%Urlaub{beginn: ~D[2025-07-01], ende: ~D[2025-07-14]})
      #=> Date.range(~D[2025-07-01], ~D[2025-07-14])

  Mit eigenen Keys:

      defmodule Vertrag do
        use Shared.Datumsbereich, beginn: :gueltig_ab, ende: :gueltig_bis
        defstruct [:gueltig_ab, :gueltig_bis]
      end

      Vertrag.to_date_range(%Vertrag{gueltig_ab: ~D[2025-01-01], gueltig_bis: ~D[2025-12-31]})
      #=> Date.range(~D[2025-01-01], ~D[2025-12-31])

  Mit einem Feld, das bereits einen Datumsbereich enthält. Das kann auch ein
  anderes Struct sein, das `use Shared.Datumsbereich` verwendet:

      defmodule Abrechnung do
        use Shared.Datumsbereich, datumsbereich: :urlaub
        defstruct [:urlaub, :betrag]
      end

      urlaub = %Urlaub{beginn: ~D[2025-07-01], ende: ~D[2025-07-14]}

      Abrechnung.to_date_range(%Abrechnung{urlaub: urlaub, betrag: 100})
      #=> %Urlaub{beginn: ~D[2025-07-01], ende: ~D[2025-07-14]}

      Shared.Datumsbereich.to_date_range(%Abrechnung{urlaub: urlaub, betrag: 100})
      #=> Date.range(~D[2025-07-01], ~D[2025-07-14])
  """
  defmacro __using__(optionen) do
    quote do
      @behaviour Shared.Datumsbereich
      @datumsbereich_optionen unquote(optionen)
      @before_compile Shared.Datumsbereich
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    optionen = Module.get_attribute(env.module, :datumsbereich_optionen)
    struct_keys = Enum.sort(Enum.map(Macro.struct_info!(env.module, env), & &1.field))

    if datumsbereich_key = Keyword.get(optionen, :datumsbereich) do
      validiere_key!(datumsbereich_key, struct_keys, env.module)

      quote do
        @impl Shared.Datumsbereich
        def to_date_range(%__MODULE__{} = struct), do: struct.unquote(datumsbereich_key)
      end
    else
      default = if :beginn not in struct_keys and :start in struct_keys, do: :start, else: :beginn
      beginn_key = Keyword.get(optionen, :beginn, default)
      ende_key = Keyword.get(optionen, :ende, :ende)

      validiere_key!(beginn_key, struct_keys, env.module)
      validiere_key!(ende_key, struct_keys, env.module)

      quote do
        @impl Shared.Datumsbereich
        def to_date_range(%__MODULE__{
              unquote(beginn_key) => %Date{} = beginn,
              unquote(ende_key) => %Date{} = ende
            }),
            do: Date.range(beginn, ende, 1)
      end
    end
  end

  @doc """
  Wandelt einen Datumsbereich `t:t/0` in ein nicht leeres, aufsteigendes
  `t:Date.Range.t/0` mit `step: 1` um.

  Ein `Date` wird zu einem eintägigen Range, ein absteigendes Range mit
  `step: -1` wird umgedreht. Bei Structs wird `c:to_date_range/1` ihres Moduls
  aufgerufen und das Ergebnis erneut umgewandelt.

  ## Beispiele

      iex> to_date_range(Date.range(~D[2025-01-01], ~D[2025-01-05]))
      Date.range(~D[2025-01-01], ~D[2025-01-05])

      iex> to_date_range(Shared.Week.range(~v[2025-01], ~v[2025-02]))
      Date.range(~D[2024-12-30], ~D[2025-01-12])

      iex> to_date_range(~D[2025-01-01])
      Date.range(~D[2025-01-01], ~D[2025-01-01])

      iex> to_date_range(~N[2025-01-01 12:00:00])
      ** (ArgumentError) NaiveDateTime definiert kein to_date_range/1

      iex> to_date_range(Date.range(~D[2025-01-05], ~D[2025-01-01], -1))
      Date.range(~D[2025-01-01], ~D[2025-01-05])

      iex> to_date_range(Date.range(~D[2025-01-01], ~D[2025-01-05], 2))
      ** (ArgumentError) Date.range(~D[2025-01-01], ~D[2025-01-05], 2) wird nicht unterstützt, nur nicht leere Date.Ranges mit step 1 oder -1
  """
  @spec to_date_range(t()) :: Date.Range.t()
  def to_date_range(range) when is_valid(range), do: range

  def to_date_range(%Date.Range{step: -1} = range) when beginn(range) >= ende(range) do
    %Date.Range{
      step: 1,
      first: range.last,
      first_in_iso_days: ende(range),
      last: range.first,
      last_in_iso_days: beginn(range)
    }
  end

  def to_date_range(%Date.Range{} = range) do
    raise ArgumentError,
          "#{inspect(range)} wird nicht unterstützt, nur nicht leere Date.Ranges mit step 1 oder -1"
  end

  def to_date_range(%Date{} = datum), do: Date.range(datum, datum)

  def to_date_range(%modul{} = wert) do
    if Code.ensure_loaded?(modul) and function_exported?(modul, :to_date_range, 1) do
      to_date_range(modul.to_date_range(wert))
    else
      raise ArgumentError, "#{inspect(modul)} definiert kein to_date_range/1"
    end
  end

  # --- Boolesche Operationen ---

  @doc """
  Prüft, ob `a` und `b` mindestens einen gemeinsamen Tag haben.

      iex> ueberschneidung?(Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-05])
      true
      iex> ueberschneidung?(Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-06])
      false
      iex> ueberschneidung?(~v[2025-01], ~m[2024-12])
      true
  """
  @spec ueberschneidung?(t(), t()) :: boolean()
  def ueberschneidung?(a, b) when are_valid(a, b),
    do: beginn(a) <= ende(b) and beginn(b) <= ende(a)

  def ueberschneidung?(%_{} = a, %_{} = b),
    do: ueberschneidung?(to_date_range(a), to_date_range(b))

  @doc """
  Prüft, ob `a` vollständig in `b` enthalten ist.

      iex> teil_von?(~D[2025-01-03], Date.range(~D[2025-01-01], ~D[2025-01-05]))
      true
      iex> teil_von?(Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-03])
      false
      iex> teil_von?(~v[2025-02], ~m[2025-01])
      true
  """
  @spec teil_von?(t(), t()) :: boolean()
  def teil_von?(a, b) when are_valid(a, b) do
    beginn(a) >= beginn(b) and ende(a) <= ende(b)
  end

  def teil_von?(%_{} = a, %_{} = b), do: teil_von?(to_date_range(a), to_date_range(b))

  @doc """
  Prüft, ob `a` vor `b` beginnt.

      iex> beginnt_frueher?(Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-02])
      true
      iex> beginnt_frueher?(~v[2025-01], ~m[2025-01])
      true
  """
  @spec beginnt_frueher?(t(), t()) :: boolean()
  def beginnt_frueher?(a, b) when are_valid(a, b),
    do: beginn(a) < beginn(b)

  def beginnt_frueher?(%_{} = a, %_{} = b),
    do: beginnt_frueher?(to_date_range(a), to_date_range(b))

  @doc """
  Prüft, ob `a` nach `b` beginnt.

      iex> beginnt_spaeter?(~D[2025-01-02], Date.range(~D[2025-01-01], ~D[2025-01-05]))
      true
  """
  @spec beginnt_spaeter?(t(), t()) :: boolean()
  def beginnt_spaeter?(a, b) when are_valid(a, b),
    do: beginn(a) > beginn(b)

  def beginnt_spaeter?(%_{} = a, %_{} = b),
    do: beginnt_spaeter?(to_date_range(a), to_date_range(b))

  @doc """
  Prüft, ob `a` vor `b` endet.

      iex> endet_frueher?(~D[2025-01-02], Date.range(~D[2025-01-01], ~D[2025-01-05]))
      true
  """
  @spec endet_frueher?(t(), t()) :: boolean()
  def endet_frueher?(a, b) when are_valid(a, b),
    do: ende(a) < ende(b)

  def endet_frueher?(%_{} = a, %_{} = b), do: endet_frueher?(to_date_range(a), to_date_range(b))

  @doc """
  Prüft, ob `a` nach `b` endet.

      iex> endet_spaeter?(Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-02])
      true
  """
  @spec endet_spaeter?(t(), t()) :: boolean()
  def endet_spaeter?(a, b) when are_valid(a, b),
    do: ende(a) > ende(b)

  def endet_spaeter?(%_{} = a, %_{} = b), do: endet_spaeter?(to_date_range(a), to_date_range(b))

  # --- Mengenoperationen ---

  @doc """
  Liefert die Tage von `basis`, die nicht in `abzuziehen` liegen, als Liste von
  `Date.Range`s. `basis` und `abzuziehen` können auch Listen von Datumsbereichen sein.

      iex> differenz(Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-03])
      [Date.range(~D[2025-01-01], ~D[2025-01-02]), Date.range(~D[2025-01-04], ~D[2025-01-05])]

      iex> differenz(
      ...>   [Date.range(~D[2025-01-01], ~D[2025-01-05]), ~D[2025-01-10]],
      ...>   [~D[2025-01-04], ~D[2025-01-02], ~D[2025-01-10]]
      ...> )
      [
        Date.range(~D[2025-01-01], ~D[2025-01-01]),
        Date.range(~D[2025-01-03], ~D[2025-01-03]),
        Date.range(~D[2025-01-05], ~D[2025-01-05])
      ]

      iex> differenz(~D[2025-01-01], [])
      [Date.range(~D[2025-01-01], ~D[2025-01-01])]

      iex> differenz([], ~m[2025-01])
      []

  Überschneidende Datumsbereiche in `basis` werden dabei _nicht_ zusammengeführt:

      iex> differenz(
      ...>   [~m[2026-01], ~v[2026-01]],
      ...>   Date.range(~D[2026-01-02], ~D[2026-02-01])
      ...> )
      [
        Date.range(~D[2026-01-01], ~D[2026-01-01]),
        Date.range(~D[2025-12-29], ~D[2026-01-01])
      ]
  """
  @spec differenz(t() | [t()], t() | [t()]) :: [Date.Range.t()]
  def differenz(basis, abzuziehen) do
    abzuziehen = List.to_tuple(vereinigung(List.wrap(abzuziehen)))
    Enum.flat_map(List.wrap(basis), &diff(to_date_range(&1), abzuziehen))
  end

  @doc """
  Liefert die gemeinsamen Tage von `a` und `b` oder `nil`, wenn es keine gibt.

      iex> ueberschneidung(~m[2025-01], ~v[2025-01])
      Date.range(~D[2025-01-01], ~D[2025-01-05])
      iex> ueberschneidung(~D[2025-01-01], ~D[2025-01-02])
      nil
  """
  @spec ueberschneidung(t(), t()) :: Date.Range.t() | nil
  def ueberschneidung(a, b) when are_valid(a, b) do
    if ueberschneidung?(a, b) do
      erster_tag = if beginnt_spaeter?(a, b), do: a.first, else: b.first
      letzter_tag = if endet_frueher?(a, b), do: a.last, else: b.last
      kalender = a.first.calendar
      Date.range(Date.convert!(erster_tag, kalender), Date.convert!(letzter_tag, kalender))
    end
  end

  def ueberschneidung(%_{} = a, %_{} = b), do: ueberschneidung(to_date_range(a), to_date_range(b))

  @doc """
  Fasst überlappende und direkt aneinandergrenzende Datumsbereiche zusammen.
  Das Ergebnis ist aufsteigend sortiert.

      iex> vereinigung([~D[2025-01-04], Date.range(~D[2025-01-01], ~D[2025-01-03]), ~D[2025-01-10]])
      [Date.range(~D[2025-01-01], ~D[2025-01-04]), Date.range(~D[2025-01-10], ~D[2025-01-10])]

      iex> vereinigung([~v[2025-02], ~m[2025-01]])
      [Date.range(~D[2025-01-01], ~D[2025-01-31])]
  """
  @spec vereinigung([t()]) :: [Date.Range.t()]
  def vereinigung(datumsbereiche) do
    datumsbereiche
    |> Enum.map(&mit_beginn/1)
    |> List.keysort(0)
    |> Enum.reduce([], &vereinige/2)
    |> Enum.reverse()
  end

  # --- Ueberlagere (Sweep-Line auf Dates) ---

  @doc """
  Zerlegt die Datumsbereiche in überschneidungsfreie Abschnitte. Jeder Abschnitt
  enthält die ursprünglichen Elemente, die ihn überdecken, siehe `Shared.Datumsbereich.Ueberlagerung`.

      iex> ueberlagere([~v[2025-01], ~D[2025-01-01]])
      [
        %Ueberlagerung{
          datumsbereich: Date.range(~D[2024-12-30], ~D[2024-12-31]),
          elemente: [~v[2025-01]]
        },
        %Ueberlagerung{
          datumsbereich: Date.range(~D[2025-01-01], ~D[2025-01-01]),
          elemente: [~D[2025-01-01], ~v[2025-01]]
        },
        %Ueberlagerung{
          datumsbereich: Date.range(~D[2025-01-02], ~D[2025-01-05]),
          elemente: [~v[2025-01]]
        }
      ]

  Ein Bereich, der am Folgetag eines anderen beginnt, schließt ohne leeren Abschnitt an:

      iex> [
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-10]),
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-03]),
      ...>   Date.range(~D[2025-01-04], ~D[2025-01-06])
      ...> ]
      ...> |> ueberlagere()
      ...> |> Enum.map(& &1.datumsbereich)
      [
        Date.range(~D[2025-01-01], ~D[2025-01-03]),
        Date.range(~D[2025-01-04], ~D[2025-01-06]),
        Date.range(~D[2025-01-07], ~D[2025-01-10])
      ]

      iex> ueberlagere([])
      []
  """
  @spec ueberlagere([t()]) :: [Ueberlagerung.t()]
  def ueberlagere(datumsbereiche) do
    {abschnitte, [], _} =
      datumsbereiche
      |> Enum.flat_map(&grenzen/1)
      |> Enum.sort()
      |> Enum.reduce({[], [], nil}, &verarbeite_grenze/2)

    Enum.reverse(abschnitte)
  end

  # --- Sortierung ---

  @doc """
  Sortiert Datumsbereiche nach Beginn und dann nach Ende.

      iex> sort([~D[2025-01-02], Date.range(~D[2025-01-01], ~D[2025-01-03])])
      [Date.range(~D[2025-01-01], ~D[2025-01-03]), ~D[2025-01-02]]
  """
  @spec sort(Enumerable.t(t())) :: list(t())
  def sort(bereiche), do: Enum.sort_by(bereiche, &to_iso_day_tuple/1)

  # --- Dauer ---

  @doc """
  Liefert die Anzahl der Tage eines Datumsbereichs, inklusive erstem und letztem Tag.

  ## Beispiele

      iex> dauer(Date.range(~D[2025-01-01], ~D[2025-01-07]))
      7

      iex> dauer(~D[2025-01-01])
      1

      iex> dauer(~m[2025-02])
      28

      iex> dauer(Date.range(~D[2025-01-05], ~D[2025-01-01], -1))
      5
  """
  @spec dauer(t()) :: pos_integer()
  def dauer(range) when is_valid(range), do: ende(range) - beginn(range) + 1
  def dauer(%_{} = datumsbereich), do: dauer(to_date_range(datumsbereich))

  # --- Private Funktionen ---

  defp validiere_key!(key, struct_keys, module) do
    if key not in struct_keys do
      raise ArgumentError,
            "#{inspect(key)} is not a key of %#{inspect(module)}{}. Keys are: #{inspect(struct_keys)}"
    end
  end

  # abzuziehen ist ein Tupel sortierter, disjunkter Date.Ranges, damit der erste
  # relevante Abzug per binärer Suche gefunden werden kann.
  defp diff(range, abzuziehen), do: diff(range, abzuziehen, index_nicht_vor(abzuziehen, range))

  defp diff(range, abzuziehen, index)
       when index >= tuple_size(abzuziehen)
       when ende(range) < beginn(elem(abzuziehen, index)),
       do: [range]

  defp diff(range, abzuziehen, index) do
    abzug = elem(abzuziehen, index)

    rest =
      if ende(abzug) < ende(range),
        do: diff(beginnend_nach(range, abzug), abzuziehen, index + 1),
        else: []

    if beginn(range) < beginn(abzug),
      do: [bis_vor(range, abzug) | rest],
      else: rest
  end

  defp bis_vor(range, abzug), do: bis_iso_tag(range, beginn(abzug) - 1)
  defp beginnend_nach(range, abzug), do: ab_iso_tag(range, ende(abzug) + 1)

  defp vereinige({_, b}, [a | rest]) when not luecke_besteht(a, b), do: [verlaengere(a, b) | rest]
  defp vereinige({_, b}, acc), do: [b | acc]

  defp mit_beginn(datumsbereich) do
    range = to_date_range(datumsbereich)
    {beginn(range), range}
  end

  defp verlaengere(a, b) when ende(b) > ende(a),
    do: %{a | last: Date.convert!(b.last, a.first.calendar), last_in_iso_days: ende(b)}

  defp verlaengere(a, _b), do: a

  # Das Ende liegt rechts-offen auf dem Folgetag, damit ein Range, der an diesem Tag
  # beginnt, nahtlos anschließt. Da :ende < :start sortiert, wird das Ende zuerst verarbeitet.
  defp grenzen(element) do
    range = to_date_range(element)

    [
      {beginn(range), :start, range.first, element},
      {ende(range) + 1, :ende, Date.add(range.last, 1), element}
    ]
  end

  defp verarbeite_grenze({iso_tag, :start, datum, element}, {abschnitte, [], _}) do
    {abschnitte, [element], {iso_tag, datum}}
  end

  defp verarbeite_grenze(
         {iso_tag, typ, _, element},
         {abschnitte, aktive, {iso_tag, _} = letzte_grenze}
       ) do
    {abschnitte, aktualisiere(aktive, typ, element), letzte_grenze}
  end

  defp verarbeite_grenze({iso_tag, typ, datum, element}, {abschnitte, aktive, {_, von}}) do
    {
      [abschnitt(von, datum, aktive) | abschnitte],
      aktualisiere(aktive, typ, element),
      {iso_tag, datum}
    }
  end

  defp aktualisiere(aktive, :start, element), do: [element | aktive]
  defp aktualisiere(aktive, :ende, element), do: List.delete(aktive, element)

  defp abschnitt(von, bis_exklusiv, aktive) do
    %Ueberlagerung{
      datumsbereich: Date.range(von, Date.convert!(Date.add(bis_exklusiv, -1), von.calendar)),
      elemente: aktive
    }
  end

  defp to_iso_day_tuple(range) when is_valid(range), do: {beginn(range), ende(range)}
  defp to_iso_day_tuple(bereich), do: to_iso_day_tuple(to_date_range(bereich))

  defp index_nicht_vor(ranges, %{} = range) when is_tuple(ranges),
    do: index_nicht_vor(ranges, beginn(range), 0, tuple_size(ranges))

  defp index_nicht_vor(ranges, tag, von, bis) when von < bis do
    mitte = div(von + bis, 2)
    datumsbereich = elem(ranges, mitte)

    if ende(datumsbereich) < tag,
      do: index_nicht_vor(ranges, tag, mitte + 1, bis),
      else: index_nicht_vor(ranges, tag, von, mitte)
  end

  defp index_nicht_vor(_ranges, _tag, von, _bis), do: von

  defp ab_iso_tag(range, iso_tag),
    do: %{range | first: iso_to_date(iso_tag, range.first.calendar), first_in_iso_days: iso_tag}

  defp bis_iso_tag(range, iso_tag),
    do: %{range | last: iso_to_date(iso_tag, range.first.calendar), last_in_iso_days: iso_tag}

  # Date.from_gregorian_days/2 schlägt für andere Kalender als Calendar.ISO fehl, daher
  # wird das Date anschließend in den gewünschten Kalender umgewandelt.
  defp iso_to_date(tag, kalender),
    do: tag |> Date.from_gregorian_days() |> Date.convert!(kalender)
end
