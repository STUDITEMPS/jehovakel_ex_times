defmodule Shared.Datumsbereich do
  @moduledoc """
  Funktionen für ganztägige Zeiträume auf Basis von `t:Date.Range.t/0`.

  Gerechnet wird direkt auf den ISO-Tagen der Ranges. Unterstützt werden nur
  aufsteigende Ranges mit `step: 1`, siehe `is_valid/1`.

  ## Beispiele

      iex> Shared.Datumsbereich.ueberschneidung?(
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-05]),
      ...>   Date.range(~D[2025-01-05], ~D[2025-01-10])
      ...> )
      true

      iex> Shared.Datumsbereich.differenz(
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-10]),
      ...>   Date.range(~D[2025-01-04], ~D[2025-01-06])
      ...> )
      [Date.range(~D[2025-01-01], ~D[2025-01-03]), Date.range(~D[2025-01-07], ~D[2025-01-10])]

      iex> Shared.Datumsbereich.vereinigung([
      ...>   Date.range(~D[2025-01-06], ~D[2025-01-10]),
      ...>   Date.range(~D[2025-01-01], ~D[2025-01-05])
      ...> ])
      [Date.range(~D[2025-01-01], ~D[2025-01-10])]

  ## Eigene Structs als Datumsbereich

  Mit `use Shared.Datumsbereich` bekommt ein Struct eine Funktion
  `to_date_range/1`, siehe `__using__/1`. `to_date_range/1` wandelt solche
  Structs in ein `Date.Range` um:

      iex> Shared.Datumsbereich.to_date_range(Shared.Month.range(~m[2025-01], ~m[2025-02]))
      Date.range(~D[2025-01-01], ~D[2025-02-28])
  """

  alias Shared.Zeitraum.Ueberlagerung

  @callback to_date_range(struct()) :: Date.Range.t()

  @doc """
  Implementiert `c:to_date_range/1` im aufrufenden Struct-Modul.

  Die Keys werden zur Compile-Zeit gegen die Felder des Structs geprüft.

  ## Optionen

    * `:datumsbereich` – Feld mit einem `Date.Range` oder einem Struct, dessen Modul
      selbst `to_date_range/1` implementiert.
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
        def to_date_range(%__MODULE__{} = struct),
          do: Shared.Datumsbereich.to_date_range(struct.unquote(datumsbereich_key))
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
            do: Date.range(beginn, ende)
      end
    end
  end

  @doc """
  Liefert ein `Date.Range` unverändert zurück. Bei einem Struct, dessen Modul
  `to_date_range/1` implementiert, wird diese Funktion aufgerufen.

  ## Beispiele

      iex> Shared.Datumsbereich.to_date_range(Date.range(~D[2025-01-01], ~D[2025-01-05]))
      Date.range(~D[2025-01-01], ~D[2025-01-05])

      iex> Shared.Datumsbereich.to_date_range(Shared.Week.range(~v[2025-01], ~v[2025-02]))
      Date.range(~D[2024-12-30], ~D[2025-01-12])

      iex> Shared.Datumsbereich.to_date_range(~D[2025-01-01])
      ** (ArgumentError) ~D[2025-01-01] ist kein Date.Range und implementiert kein to_date_range/1
  """
  @spec to_date_range(Date.Range.t() | struct()) :: Date.Range.t()
  def to_date_range(%Date.Range{} = range), do: range

  def to_date_range(%modul{} = wert) do
    if Code.ensure_loaded?(modul) and function_exported?(modul, :to_date_range, 1),
      do: modul.to_date_range(wert),
      else: kein_date_range!(wert)
  end

  def to_date_range(wert), do: kein_date_range!(wert)

  defp kein_date_range!(wert) do
    raise ArgumentError,
          "#{inspect(wert)} ist kein Date.Range und implementiert kein to_date_range/1"
  end

  defp validiere_key!(key, struct_keys, module) do
    if key not in struct_keys do
      raise ArgumentError,
            "#{inspect(key)} is not a key of %#{inspect(module)}{}. Keys are: #{inspect(struct_keys)}"
    end
  end

  defmacrop beginn(range), do: quote(do: unquote(range).first_in_iso_days)
  defmacrop ende(range), do: quote(do: unquote(range).last_in_iso_days)

  defguard is_valid(range)
           when is_struct(range, Date.Range) and range.step == 1 and beginn(range) <= ende(range)

  defguard are_valid(a, b) when is_valid(a) and is_valid(b)

  # --- Boolesche Operationen ---

  @spec ueberschneidung?(Date.Range.t(), Date.Range.t()) :: boolean()
  def ueberschneidung?(a, b) when are_valid(a, b) do
    beginn(a) <= ende(b) and beginn(b) <= ende(a)
  end

  @spec teil_von?(Date.Range.t(), Date.Range.t()) :: boolean()
  def teil_von?(zu_testend, zeitraum) when are_valid(zu_testend, zeitraum) do
    beginn(zu_testend) >= beginn(zeitraum) and
      ende(zu_testend) <= ende(zeitraum)
  end

  @spec beginnt_frueher?(Date.Range.t(), Date.Range.t()) :: boolean()
  def beginnt_frueher?(a, b) when are_valid(a, b),
    do: beginn(a) < beginn(b)

  @spec beginnt_spaeter?(Date.Range.t(), Date.Range.t()) :: boolean()
  def beginnt_spaeter?(a, b) when are_valid(a, b),
    do: beginn(a) > beginn(b)

  @spec endet_frueher?(Date.Range.t(), Date.Range.t()) :: boolean()
  def endet_frueher?(a, b) when are_valid(a, b),
    do: ende(a) < ende(b)

  @spec endet_spaeter?(Date.Range.t(), Date.Range.t()) :: boolean()
  def endet_spaeter?(a, b) when are_valid(a, b),
    do: ende(a) > ende(b)

  # --- Mengenoperationen ---

  @spec differenz(Date.Range.t(), Date.Range.t()) :: [Date.Range.t()]
  def differenz(a, b) when are_valid(a, b) do
    cond do
      not ueberschneidung?(a, b) -> [a]
      teil_von?(a, b) -> []
      not beginnt_spaeter?(b, a) -> [teil_nach(a, b)]
      not endet_frueher?(b, a) -> [teil_vor(a, b)]
      true -> [teil_vor(a, b), teil_nach(a, b)]
    end
  end

  defp teil_vor(a, b), do: Date.range(a.first, Date.add(b.first, -1))
  defp teil_nach(a, b), do: Date.range(Date.add(b.last, 1), a.last)

  @spec ueberschneidung(Date.Range.t(), Date.Range.t()) :: Date.Range.t() | nil
  def ueberschneidung(a, b) when are_valid(a, b) do
    if ueberschneidung?(a, b) do
      erster_tag = if beginnt_spaeter?(a, b), do: a.first, else: b.first
      letzter_tag = if endet_frueher?(a, b), do: a.last, else: b.last
      Date.range(erster_tag, letzter_tag)
    end
  end

  @spec vereinigung([Date.Range.t()]) :: [Date.Range.t()]
  def vereinigung(ranges) do
    ranges
    |> Enum.sort_by(&beginn/1)
    |> vereinige()
  end

  defp vereinige([]), do: []
  defp vereinige([range]) when is_valid(range), do: [range]

  defp vereinige([a, b | rest]) when are_valid(a, b) do
    if besteht_luecke?(a, b) do
      [a | vereinige([b | rest])]
    else
      letzter_tag = if endet_spaeter?(a, b), do: a.last, else: b.last
      vereinige([Date.range(a.first, letzter_tag) | rest])
    end
  end

  defp besteht_luecke?(a, b), do: beginn(b) - ende(a) > 1

  # --- Ueberlagere (Sweep-Line auf Dates) ---

  @spec ueberlagere([Date.Range.t()]) :: [Ueberlagerung.t()]
  def ueberlagere(ranges) do
    {abschnitte, [], _} =
      ranges
      |> Enum.flat_map(&grenzen/1)
      |> Enum.sort()
      |> Enum.reduce({[], [], nil}, &verarbeite_grenze/2)

    Enum.reverse(abschnitte)
  end

  # Das Ende liegt rechts-offen auf dem Folgetag, damit ein Range, der an diesem Tag
  # beginnt, nahtlos anschließt. Da :ende < :start sortiert, wird das Ende zuerst verarbeitet.
  defp grenzen(range) when is_valid(range) do
    [
      {beginn(range), :start, range.first, range},
      {ende(range) + 1, :ende, Date.add(range.last, 1), range}
    ]
  end

  defp verarbeite_grenze({tag, :start, datum, range}, {abschnitte, [], _}) do
    {abschnitte, [range], {tag, datum}}
  end

  defp verarbeite_grenze({tag, typ, _, range}, {abschnitte, aktive, {tag, _} = letzte_grenze}) do
    {abschnitte, aktualisiere(aktive, typ, range), letzte_grenze}
  end

  defp verarbeite_grenze({tag, typ, datum, range}, {abschnitte, aktive, {_, von}}) do
    {
      [abschnitt(von, datum, aktive) | abschnitte],
      aktualisiere(aktive, typ, range),
      {tag, datum}
    }
  end

  defp aktualisiere(aktive, :start, range), do: [range | aktive]
  defp aktualisiere(aktive, :ende, range), do: List.delete(aktive, range)

  defp abschnitt(von, bis_exklusiv, aktive) do
    %Ueberlagerung{
      zeitraum: Date.range(von, Date.add(bis_exklusiv, -1)),
      elemente: aktive
    }
  end

  # --- Vergleichsoperationen ---

  @spec compare(Date.Range.t(), Date.Range.t()) :: :lt | :eq | :gt
  def compare(a, b) when are_valid(a, b) do
    a_tage = {beginn(a), ende(a)}
    b_tage = {beginn(b), ende(b)}

    cond do
      a_tage < b_tage -> :lt
      a_tage > b_tage -> :gt
      true -> :eq
    end
  end

  # --- Dauer ---

  @type einheit :: :duration | :days | :hours | :minutes | :seconds | :weeks

  defguard is_einheit(einheit)
           when einheit in [:duration, :days, :hours, :minutes, :seconds, :weeks]

  @spec dauer(Date.Range.t(), einheit()) :: non_neg_integer() | Timex.Duration.t()
  def dauer(range, einheit) when is_valid(range) and is_einheit(einheit) do
    tage = ende(range) - beginn(range) + 1

    case einheit do
      :duration -> Timex.Duration.from_days(tage)
      :days -> tage
      :hours -> tage * 24
      :minutes -> tage * 24 * 60
      :seconds -> tage * 24 * 60 * 60
      :weeks -> div(tage, 7)
    end
  end
end
