defmodule Shared.Zeitraum.DateRange do
  @moduledoc false

  alias Shared.Zeitraum.Ueberlagerung

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
