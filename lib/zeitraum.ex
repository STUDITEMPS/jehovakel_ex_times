defmodule Shared.Zeitraum do
  @moduledoc """
  Funktionen zur Handhabung von Zeiträumen.

  Diese funktionen arbeiten auf dem `Shared.ZeitraumProtokoll`. Es existieren
  implementierngen für: `t:Shared.Week.t/0`, `t:Shared.Month.t/0` `t:Date.t/0`
  und `t:Date.Range.t/0`. Weitere Entities können einfach durch implementierung
  des ZeitraumProtokolls mit unterstützt werden.

  Lassen sich alle Eingaben als `t:Date.Range.t/0` darstellen, wird mit Date.Ranges
  gerechnet und es werden Date.Ranges zurückgegeben. Andernfalls wird mit
  `t:Timex.Interval.t/0` gerechnet.
  """

  require Shared.Zeitraum.DateRange, as: DateRange

  alias Shared.Zeitperiode
  alias Shared.Zeitraum.Ueberlagerung
  alias Shared.Zeitraum.Vereinigung
  alias Shared.ZeitraumProtokoll

  @type t :: ZeitraumProtokoll.t()

  @doc """
  Konvertiert einen `t:Shared.Zeitraum.t/0` in ein `t:Timex.Interval.t/0`.

  ## Beispiel:

    iex> %Timex.Interval{} = als_intervall(~D[2025-01-01])
  """
  @spec als_intervall(t()) :: Timex.Interval.t()
  def als_intervall(%Timex.Interval{} = intervall), do: intervall

  def als_intervall(%Date.Range{step: 1} = range),
    do: Zeitperiode.new(range.first, range.last)

  def als_intervall(%Date.Range{}) do
    raise ArgumentError, "Date Ranges with steps sizes other than 1 are not supported"
  end

  def als_intervall(zeitraum), do: als_intervall(ZeitraumProtokoll.zeitraum(zeitraum))

  @type als_daterange_opts :: [truncate_from: boolean, truncate_until: boolean]
  @spec als_daterange(t(), als_daterange_opts()) :: Date.Range.t()
  @doc """
  Konvertiert einen `t:Shared.Zeitraum.t/0` in einen `t:Date.Range.t/0`.

  ## Beispiel:

    iex> als_daterange(~Z[2025-01-01/2025-01-03])
    Date.range(~D[2025-01-01], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 00:00:00/2025-01-03 00:00:00])
    Date.range(~D[2025-01-01], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 00:00:00/2025-01-03 12:00:00])
    Date.range(~D[2025-01-01], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 12:00:00/2025-01-03 00:00:00])
    Date.range(~D[2025-01-02], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 12:00:00/2025-01-03 12:00:00])
    Date.range(~D[2025-01-02], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 00:00:00/2025-01-03 12:00:00], truncate_until: false)
    Date.range(~D[2025-01-01], ~D[2025-01-03])

    iex > als_daterange(~Z[2025-01-01 12:00:00/2025-01-03 12:00:00], truncate_from: false)
    Date.range(~D[2025-01-01], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 12:00:00/2025-01-01 13:00:00], truncate_from: false, truncate_until: false)
    Date.range(~D[2025-01-01], ~D[2025-01-01])

    iex> als_daterange(~Z[2025-01-01 00:00:00/2025-01-01 12:00:00]) |> Enum.empty?()
    true

    iex> als_daterange(~Z[2025-01-01 10:00:00/2025-01-02 12:00:00]) |> Enum.empty?()
    true
  """
  def als_daterange(zeitraum, opts \\ [])

  def als_daterange(range, _opts) when DateRange.is_valid(range), do: range

  def als_daterange(%Timex.Interval{} = intervall, opts) do
    from_date = NaiveDateTime.to_date(intervall.from)
    until_date = NaiveDateTime.to_date(intervall.until)

    from_time = NaiveDateTime.to_time(intervall.from)
    until_time = NaiveDateTime.to_time(intervall.until)

    truncate_from = Keyword.get(opts, :truncate_from, true)
    truncate_until = Keyword.get(opts, :truncate_until, true)

    from =
      if truncate_from and from_time != ~T[00:00:00], do: Date.add(from_date, 1), else: from_date

    until =
      if truncate_until or until_time == ~T[00:00:00],
        do: Date.add(until_date, -1),
        else: until_date

    Date.range(from, until, 1)
  end

  def als_daterange(zeitraum, opts), do: als_daterange(normalisiere(zeitraum), opts)

  @doc """
  Berechnet die Dauer eines Zeitraums.

  Die Einheit kann `:seconds`, `:minutes`, `:hours`, `:days`, `:weeks`, `:months`
  oder `:years` sein.

  Siehe `Timex.Interval.duration/2`

  Alle einheiten außer `:duration` geben ein `t:integer/0` zurück. Um eine
  Fließkommazahl zu erhalten verwende `dauer/1` und `Timex.Duration.to_hours/2`, etc.

  ## Beispiel:
    iex> dauer(~D[2025-01-01])
    %Timex.Duration{megaseconds: 0, microseconds: 0, seconds: 86400}

    iex> dauer(~D[2025-01-01], :hours)
    24
  """
  @spec dauer(t, atom) :: Timex.Duration.t() | {:error, any}
  def dauer(zeitraum, einheit \\ :duration)

  def dauer(range, einheit) when DateRange.is_valid(range) and DateRange.is_einheit(einheit),
    do: DateRange.dauer(range, einheit)

  def dauer(%Timex.Interval{} = intervall, einheit),
    do: Timex.Interval.duration(intervall, einheit)

  def dauer(zeitraum, einheit) do
    case normalisiere(zeitraum) do
      range when DateRange.is_valid(range) and DateRange.is_einheit(einheit) ->
        DateRange.dauer(range, einheit)

      zeitraum ->
        Timex.Interval.duration(als_intervall(zeitraum), einheit)
    end
  end

  @doc """
  Testet zwei Zeiträume auf Überschneidung

  ## Beispiel

    iex> ueberschneidung?(~D[2025-01-01], ~v[2025-02])
    false

    iex> ueberschneidung?(~v[2025-05], ~m[2025-01])
    true
  """
  @spec ueberschneidung?(t, t) :: boolean
  def ueberschneidung?(a, b) when DateRange.are_valid(a, b),
    do: DateRange.ueberschneidung?(a, b)

  def ueberschneidung?(%Timex.Interval{} = a, %Timex.Interval{} = b),
    do: Timex.Interval.overlaps?(a, b)

  def ueberschneidung?(a, b) do
    {a, b} = normalisiere(a, b)
    ueberschneidung?(a, b)
  end

  @doc """
  Testet ob ein Zeitraum vollständig in einem anderen enthalten ist.

  ## Beispiel

    iex> teil_von?(~v[2025-05], ~m[2025-01])
    false

    iex> teil_von?(~D[2025-01-01], ~m[2025-01])
    true

    iex> teil_von?(~D[2025-01-01], ~D[2025-01-01])
    true
  """
  @spec teil_von?(zu_testende_periode :: t, periode :: t) :: boolean
  def teil_von?(zu_testender_zeitraum, zeitraum)
      when DateRange.are_valid(zu_testender_zeitraum, zeitraum),
      do: DateRange.teil_von?(zu_testender_zeitraum, zeitraum)

  def teil_von?(%Timex.Interval{} = zu_testender_zeitraum, %Timex.Interval{} = zeitraum),
    do: Timex.Interval.contains?(zeitraum, zu_testender_zeitraum)

  def teil_von?(zu_testender_zeitraum, zeitraum) do
    {zu_testender_zeitraum, zeitraum} = normalisiere(zu_testender_zeitraum, zeitraum)
    teil_von?(zu_testender_zeitraum, zeitraum)
  end

  @doc """
  Berechnet die differenz von
  Zieht von einer Liste von Zeitperioden eine andere Liste von Zeitperioden ab,
  so dass alle Überlappungen mit der zweiten Liste aus der ersten Liste entfernt
  werden.

  ## Beispiel

  iex> differenz(~D[2025-01-01], Timex.Interval.new(from: ~U[2025-01-01T16:00:00Z], until: ~U[2025-01-02T00:00:00Z]))
  [%Timex.Interval{from: ~N[2025-01-01 00:00:00], until: ~N[2025-01-01 16:00:00], step: [seconds: 1]}]

  iex> differenz(~v[2024-01], [~D[2024-01-01], ~D[2024-01-04], ~D[2024-01-07]])
  [Date.range(~D[2024-01-02], ~D[2024-01-03]), Date.range(~D[2024-01-05], ~D[2024-01-06])]
  """
  @spec differenz(list(t()) | t(), list(t()) | t()) :: list(t())
  def differenz(basis_intervalle, abzuziehende_intervalle) when is_list(basis_intervalle) do
    Enum.flat_map(basis_intervalle, &differenz(&1, abzuziehende_intervalle))
  end

  def differenz(basis_intervall, []) do
    [basis_intervall]
  end

  def differenz(basis_intervall, [abzuziehendes_intervall]) do
    differenz(basis_intervall, abzuziehendes_intervall)
  end

  def differenz(basis_intervall, [abzuziehendes_intervall | rest]) do
    basis_intervall |> differenz(abzuziehendes_intervall) |> differenz(rest)
  end

  # Zieht von einer einzelnen Zeitperiode eine andere ab. Für tolle Beispiele siehe
  # https://hexdocs.pm/timex/3.5.0/Timex.Interval.html#difference/2
  def differenz(basis_intervall, abzuziehendes_intervall)
      when DateRange.are_valid(basis_intervall, abzuziehendes_intervall),
      do: DateRange.differenz(basis_intervall, abzuziehendes_intervall)

  def differenz(%Timex.Interval{} = basis_intervall, %Timex.Interval{} = abzuziehendes_intervall),
    do: Timex.Interval.difference(basis_intervall, abzuziehendes_intervall)

  def differenz(basis_intervall, abzuziehendes_intervall) do
    {basis_intervall, abzuziehendes_intervall} =
      normalisiere(basis_intervall, abzuziehendes_intervall)

    differenz(basis_intervall, abzuziehendes_intervall)
  end

  @doc """
  Überlagert eine Liste von Zeiträumen zu einer überschneidungsfreien Partition.

  Nimmt eine Liste von Zeiträumen (beliebige Typen die `t:Shared.ZeitraumProtokoll.t/0`
  implementieren) und erzeugt eine Liste von `t:Ueberlagerung.t/0` Structs, in der sich
  keine Zeiträume mehr überschneiden. Jede Überlagerung enthält die Liste der ursprünglichen
  Elemente, die den jeweiligen Abschnitt überdecken.

  Die resultierenden Überlagerungen implementieren selbst das `t:Shared.ZeitraumProtokoll.t/0`
  und können direkt mit `differenz/2`, `ueberschneidung/2`, etc. verwendet werden.

  ## Beispiel

  Nicht überlappende Zeiträume bleiben getrennt:

      iex> ueberlagere([~D[2025-01-01], ~D[2025-01-03]])
      [
        %Ueberlagerung{zeitraum: ~Z[2025-01-01 00:00:00/2025-01-02 00:00:00], elemente: [~D[2025-01-01]]},
        %Ueberlagerung{zeitraum: ~Z[2025-01-03 00:00:00/2025-01-04 00:00:00], elemente: [~D[2025-01-03]]},
      ]

  Überlappende Zeiträume werden aufgeteilt. Die Überlappung enthält beide Elemente:

      iex> mo_bis_mi = ~Z[2025-01-06/2025-01-09]
      iex> di_bis_do = ~Z[2025-01-07/2025-01-10]
      iex> ueberlagere([mo_bis_mi, di_bis_do]) |> Enum.sort_by(& &1.zeitraum.from)
      [
        %Ueberlagerung{zeitraum: ~Z[2025-01-06/2025-01-07], elemente: [~Z[2025-01-06/2025-01-09]]},
        %Ueberlagerung{zeitraum: ~Z[2025-01-07/2025-01-09], elemente: [~Z[2025-01-07/2025-01-10], ~Z[2025-01-06/2025-01-09]]},
        %Ueberlagerung{zeitraum: ~Z[2025-01-09/2025-01-10], elemente: [~Z[2025-01-07/2025-01-10]]},
      ]
  """
  @spec ueberlagere(list(t())) :: list(Ueberlagerung.t())
  def ueberlagere(zeitraeume) do
    # Nur bei reinen Date.Ranges, da die Überlagerung die ursprünglichen Elemente enthalten muss.
    if Enum.all?(zeitraeume, &DateRange.is_valid(&1)),
      do: DateRange.ueberlagere(zeitraeume),
      else: Ueberlagerung.aus_zeitraeumen(zeitraeume)
  end

  @doc """
  Ermittelt die Überschneidung zweier Zeitperioden.

  Die Überschneidung kann mithilfe der differenz ermittelt werden:

  <pre>
  AB - (AB - BC) = B
  AB - (A) = B
  B = B
  </pre>

  ## Beispiel

  iex> ueberschneidung(~v[2025-05], ~m[2025-01])
  Date.range(~D[2025-01-27], ~D[2025-01-31])

  iex> ueberschneidung(~D[2025-01-01], ~D[2025-01-02])
  nil

  iex> ueberschneidung(~D[2025-01-01], ~D[2025-01-01])
  Date.range(~D[2025-01-01], ~D[2025-01-01])
  """
  @spec ueberschneidung(t(), t()) :: t() | nil
  def ueberschneidung(a, b) when DateRange.are_valid(a, b), do: DateRange.ueberschneidung(a, b)

  def ueberschneidung(%Timex.Interval{} = a, %Timex.Interval{} = b) do
    case differenz(a, differenz(a, b)) do
      [ueberschneidung] -> ueberschneidung
      [] -> nil
    end
  end

  def ueberschneidung(a, b) do
    {a, b} = normalisiere(a, b)
    ueberschneidung(a, b)
  end

  @doc """
  Bildet die Vereinigung zweier Zeiträume.

  Sollten diese nicht überlappen werden beide als tuple zurückgegeben.

  ## Beispiel

  iex> vereinigung(~v[2025-05], ~m[2025-01])
  Date.range(~D[2025-01-01], ~D[2025-02-02])

  iex> vereinigung(~v[2025-05], ~v[2025-04])
  Date.range(~D[2025-01-20], ~D[2025-02-02])

  iex> vereinigung(~v[2025-05], ~v[2025-03])
  {Date.range(~D[2025-01-13], ~D[2025-01-19]), Date.range(~D[2025-01-27], ~D[2025-02-02])}
  """
  @spec vereinigung(t(), t()) :: t() | {t(), t()}
  def vereinigung(a, b) do
    case vereinigung([a, b]) do
      [a, b] -> {a, b}
      [c] -> c
    end
  end

  @doc """
  Bildet die Vereinigung aller Zeiträume.

  Gibt eine Liste nicht überlappender Zeiträume zurück.

  ## Beispiel

  iex> vereinigung([~v[2025-05], ~m[2025-01]])
  [Date.range(~D[2025-01-01], ~D[2025-02-02])]

  iex> vereinigung([~v[2025-05], ~v[2025-04]])
  [Date.range(~D[2025-01-20], ~D[2025-02-02])]

  iex> vereinigung([~v[2025-05], ~v[2025-03]])
  [Date.range(~D[2025-01-13], ~D[2025-01-19]), Date.range(~D[2025-01-27], ~D[2025-02-02])]

  iex> vereinigung([~D[2025-01-01], ~D[2025-01-02], ~D[2025-01-07], ~D[2025-01-02], ~D[2025-01-05], ~v[2025-01]])
  [Date.range(~D[2024-12-30], ~D[2025-01-05]), Date.range(~D[2025-01-07], ~D[2025-01-07])]

  """
  @spec vereinigung([t()]) :: [t()]
  def vereinigung(zeitraeume) when is_list(zeitraeume) do
    normalisierte_zeitraeume = Enum.map(zeitraeume, &normalisiere/1)

    if Enum.all?(normalisierte_zeitraeume, &DateRange.is_valid(&1)),
      do: DateRange.vereinigung(normalisierte_zeitraeume),
      else: Vereinigung.aus_zeitraeumen(zeitraeume)
  end

  @doc """
  Testet ob der beginn des ersten Zeitraums vor dem des zweiten liegt.

  ## Beispiel

    iex> beginnt_vor?(~D[2025-01-01], ~D[2025-01-02])
    true

    iex> beginnt_vor?(~D[2025-01-02], ~D[2025-01-01])
    false

    iex> beginnt_vor?(~m[2025-01], ~D[2025-01-01])
    false
  """
  @spec beginnt_vor?(t(), t()) :: boolean()
  def beginnt_vor?(a, b) when DateRange.are_valid(a, b), do: DateRange.beginnt_frueher?(a, b)

  def beginnt_vor?(%Timex.Interval{left_open: lo} = a, %Timex.Interval{left_open: lo} = b),
    do: NaiveDateTime.before?(a.from, b.from)

  def beginnt_vor?(a, b) do
    {a, b} = normalisiere(a, b)
    beginnt_vor?(a, b)
  end

  @doc """
  Testet ob der beginn des ersten Zeitraums nach dem des zweiten liegt.

  ## Beispiel

    iex> beginnt_nach?(~D[2025-01-01], ~D[2025-01-02])
    false

    iex> beginnt_nach?(~D[2025-01-02], ~D[2025-01-01])
    true

    iex> beginnt_nach?(~m[2025-01], ~D[2025-01-01])
    false
  """
  @spec beginnt_nach?(t(), t()) :: boolean()
  def beginnt_nach?(a, b) when DateRange.are_valid(a, b), do: DateRange.beginnt_spaeter?(a, b)

  def beginnt_nach?(%Timex.Interval{left_open: lo} = a, %Timex.Interval{left_open: lo} = b),
    do: NaiveDateTime.after?(a.from, b.from)

  def beginnt_nach?(a, b) do
    {a, b} = normalisiere(a, b)
    beginnt_nach?(a, b)
  end

  @doc """
  Testet ob das Ende des ersten Zeitraums vor dem des zweiten liegt.

  ## Beispiel

    iex> endet_vor?(~D[2025-01-01], ~D[2025-01-02])
    true

    iex> endet_vor?(~D[2025-01-02], ~D[2025-01-01])
    false

    iex> endet_vor?(~m[2025-01], ~D[2025-01-31])
    false
  """
  @spec endet_vor?(t(), t()) :: boolean()
  def endet_vor?(a, b) when DateRange.are_valid(a, b), do: DateRange.endet_frueher?(a, b)

  def endet_vor?(%Timex.Interval{right_open: ro} = a, %Timex.Interval{right_open: ro} = b),
    do: NaiveDateTime.before?(a.until, b.until)

  def endet_vor?(a, b) do
    {a, b} = normalisiere(a, b)
    endet_vor?(a, b)
  end

  @doc """
  Testet ob das Ende des ersten Zeitraums nach dem des zweiten liegt.

  ## Beispiel

    iex> endet_nach?(~D[2025-01-01], ~D[2025-01-02])
    false

    iex> endet_nach?(~D[2025-01-02], ~D[2025-01-01])
    true

    iex> endet_nach?(~m[2025-01], ~D[2025-01-31])
    false
  """
  @spec endet_nach?(t(), t()) :: boolean()
  def endet_nach?(a, b) when DateRange.are_valid(a, b), do: DateRange.endet_spaeter?(a, b)

  def endet_nach?(%Timex.Interval{right_open: ro} = a, %Timex.Interval{right_open: ro} = b),
    do: NaiveDateTime.after?(a.until, b.until)

  def endet_nach?(a, b) do
    {a, b} = normalisiere(a, b)
    endet_nach?(a, b)
  end

  @doc """
  Vergleicht zwei Zeiträume zuerst nach Start und dann nach Ende.

  Kann auch benutzt werden um Zeiträume in einer Liste zu sortieren.

  ## Beispiel

      iex> Enum.sort([
      ...>   ~m[2025-05],
      ...>   ~D[2025-05-20],
      ...>   Shared.Week.from_day!(~D[2025-05-01]),
      ...>   Shared.Week.from_day!(~D[2025-05-31]),
      ...>   Date.range(~D[2025-05-19], ~D[2025-05-20])
      ...> ], Shared.Zeitraum)
      [~v[2025-18], ~m[2025-05], Date.range(~D[2025-05-19], ~D[2025-05-20]), ~D[2025-05-20], ~v[2025-22]]

  """
  @spec compare(t(), t()) :: :lt | :eq | :gt
  def compare(a, b) when DateRange.are_valid(a, b), do: DateRange.compare(a, b)

  def compare(
        %Timex.Interval{left_open: lo, right_open: ro} = a,
        %Timex.Interval{left_open: lo, right_open: ro} = b
      ) do
    with :eq <- NaiveDateTime.compare(a.from, b.from) do
      NaiveDateTime.compare(a.until, b.until)
    end
  end

  def compare(%Timex.Interval{}, %Timex.Interval{}) do
    raise ArgumentError, "Cannot compare intervals with different open/closed status"
  end

  def compare(%type{} = a, %type{} = b) do
    if function_exported?(type, :compare, 2),
      do: type.compare(a, b),
      else: compare(normalisiere(a), normalisiere(b))
  end

  def compare(a, b) do
    {a, b} = normalisiere(a, b)
    compare(a, b)
  end

  @doc """
  Sigil zur Erstellung von Zeiträumen.

  Unterstützt aktuell nur Daten und Monate.

  > [!NOTICE]
  > Wenn der Range-Modifier (r) angegeben wird, dann werden ggf. Date-, Week- &
  > Month-Ranges ausgegeben, diese sind end inclusive (right-closed). Ohne
  > Range-Modifier (r) werden immer Shared.Zeitperiode.t() ausgegeben, diese sind
  > end exclusive (right-open).
  > Die Angabe im Sigil selbst ist immer end exclusive.

  ## Beispiel

      iex> ~Z[2025-01/2025-03]
      Shared.Zeitperiode.new(~N[2025-01-01 00:00:00], ~N[2025-03-01 00:00:00])

      iex> ~Z[2025-01/2025-03]r
      Shared.Month.range(~m[2025-01], ~m[2025-02])

      iex> ~Z[2025-W01/2025-W02]
      Shared.Zeitperiode.new(~N[2024-12-30 00:00:00], ~N[2025-01-06 00:00:00])

      iex> ~Z[2025-W01/2025-W02]r
      Shared.Week.range(~v[2025-01], ~v[2025-01])

      iex> ~Z[2025-01-01/2025-01-20]
      Shared.Zeitperiode.new(~N[2025-01-01 00:00:00], ~N[2025-01-20 00:00:00])

      iex> ~Z[2025-01-01/2025-01-20]r
      Date.range(~D[2025-01-01], ~D[2025-01-19])

      iex> ~Z[2025-01-01 08:00:00/2025-01-20T16:30:00]
      Shared.Zeitperiode.new(~N[2025-01-01 08:00:00], ~N[2025-01-20 16:30:00])

  Date Ranges laufen _immer_ vorwärts, d.h. mit einem Step von 1. Damit können
  sie dann auch leer sein.

      iex> ~Z[2025-01-01/2025-01-01]r
      Date.range(~D[2025-01-01], ~D[2024-12-31], 1)

      iex> Enum.empty?(~Z[2025-01-01/2025-01-01]r)
      true

  """
  @spec sigil_Z(String.t(), keyword()) :: t() | no_return()
  defmacro sigil_Z({:<<>>, _context, [string]}, flags) do
    string
    |> sigil_z_format()
    |> sigil_z_quote(string, ?r in flags)
  end

  defp sigil_z_format(string) do
    cond do
      String.match?(string, ~r/\d{4}-\d{2}-\d{2}\/\d{4}-\d{2}-\d{2}/) ->
        :date

      String.match?(string, ~r/\d{4}-W\d{2}\/\d{4}-W\d{2}/) ->
        :week

      String.match?(string, ~r/\d{4}-\d{2}\/\d{4}-\d{2}/) ->
        :month

      String.match?(
        string,
        ~r/\d{4}-\d{2}-\d{2}(T| )\d{2}:\d{2}:\d{2}\/\d{4}-\d{2}-\d{2}(T| )\d{2}:\d{2}:\d{2}/
      ) ->
        :naive_date_time

      :else ->
        raise ArgumentError, "Invalid format: #{inspect(string)}"
    end
  end

  defp sigil_z_quote(:date, string, true = _range?) do
    quote do
      [left, right] = unquote(to_date_sigils(string))

      Date.range(left, Date.add(right, -1), 1)
    end
  end

  defp sigil_z_quote(:date, string, false = _range?) do
    quote do
      Shared.Zeitperiode.new(unquote_splicing(to_date_sigils(string)), right_open: true)
    end
  end

  defp sigil_z_quote(:week, string, true = _range?) do
    quote do
      [left, right] = String.split(unquote(string), "/", parts: 2)

      Shared.Week.range(
        Shared.Week.parse!(left),
        Shared.Week.parse!(right) |> Shared.Week.shift(-1)
      )
    end
  end

  defp sigil_z_quote(:week, string, false = _range?) do
    quote do
      [left, right] = String.split(unquote(string), "/", parts: 2)
      left_date = Shared.Week.parse!(left) |> Shared.Week.first_day()
      right_date = Shared.Week.parse!(right) |> Shared.Week.first_day()

      Shared.Zeitperiode.new(left_date, right_date, right_open: true)
    end
  end

  defp sigil_z_quote(:month, string, true = _range?) do
    quote do
      [left, right] = unquote(to_month_sigils(string))
      Shared.Month.range(left, Shared.Month.shift(right, -1))
    end
  end

  defp sigil_z_quote(:month, string, false = _range?) do
    quote do
      [left, right] = unquote(to_month_sigils(string))
      left_date = Shared.Month.first_day(left)
      right_date = Shared.Month.first_day(right)
      Shared.Zeitperiode.new(left_date, right_date, right_open: true)
    end
  end

  defp sigil_z_quote(:naive_date_time, string, _range?) do
    quote do
      Shared.Zeitperiode.new(unquote_splicing(to_naive_date_time_sigils(string)))
    end
  end

  @month_sigil_context [delimiter: "[", context: Elixir, imports: [{2, Shared.Month}]]
  defp to_month_sigils(string), do: to_sigils(string, :sigil_m, @month_sigil_context)

  @date_sigil_context [delimiter: "[", context: Elixir, imports: [{2, Kernel}]]
  defp to_date_sigils(string), do: to_sigils(string, :sigil_D, @date_sigil_context)

  @naive_date_time_sigil_context [delimiter: "[", context: Elixir, imports: [{2, Kernel}]]
  defp to_naive_date_time_sigils(string),
    do: to_sigils(string, :sigil_N, @naive_date_time_sigil_context)

  defp to_sigils(string, sigil, context) do
    string
    |> String.split("/", parts: 2)
    |> Enum.map(&{:<<>>, [], [&1]})
    |> Enum.map(&{sigil, context, [&1, []]})
  end

  defp normalisiere(zeitraum) do
    case ZeitraumProtokoll.zeitraum(zeitraum) do
      range when DateRange.is_valid(range) -> range
      zeitraum -> als_intervall(zeitraum)
    end
  end

  defp normalisiere(a, b) do
    case {normalisiere(a), normalisiere(b)} do
      {a, b} when DateRange.are_valid(a, b) -> {a, b}
      {a, b} -> {als_intervall(a), als_intervall(b)}
    end
  end
end
