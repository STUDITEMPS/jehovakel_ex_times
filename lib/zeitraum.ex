defmodule Shared.Zeitraum do
  @moduledoc """
  Funktionen zu arbeit mit Zeiträumen.

  Zeiträume sind Structs die das `Shared.ZeitraumProtokoll` implemetieren.
  Es gibt vordefinierte Implementierungen für `Date`, `Date.Range`,
  `Shared.Week`, `Shared.Month` und `Timex.Interval`

  Für andere structs kann das Zeitraum Protokoll einfach wie folgt implementiert werden:

      defimpl Shared.ZeitraumProtokoll, for: MyApp.Arbeitszeit do
        def als_intervall(%{start: start, ende: ende}) do
          Shared.Zeitperiode.new(start, ende)
        end
      end

  """
  alias Shared.ZeitraumProtokoll

  @type t :: ZeitraumProtokoll.t()

  @type duration_unit ::
          :duration | :seconds | :minutes | :hours | :days | :weeks | :months | :years

  @doc """
  Konvertiert einen Zeitraum in ein Timex.Interval
  """
  @spec als_intervall(t) :: Timex.Interval.t()
  defdelegate als_intervall(zeitraum), to: ZeitraumProtokoll

  @type als_daterange_opts :: [truncate_from: boolean, truncate_until: boolean]
  @spec als_daterange(t(), als_daterange_opts()) :: Date.Range.t()
  @doc """
  Konvertiert einen `t:Shared.Zeitraum.t/0` in einen `t:Date.Range.t/0`.

  ## Beispiel:

    iex> als_daterange(~Z[2025-01-01/2025-01-03])
    Date.range(~D[2025-01-01], ~D[2025-01-03])

    iex> als_daterange(~Z[2025-01-01 12:00:00/2025-01-03 00:00:00])
    Date.range(~D[2025-01-02], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 00:00:00/2025-01-03 12:00:00])
    Date.range(~D[2025-01-01], ~D[2025-01-02])

    iex> als_daterange(~Z[2025-01-01 00:00:00/2025-01-03 12:00:00], truncate_until: false)
    Date.range(~D[2025-01-01], ~D[2025-01-03])

    iex> als_daterange(~Z[2025-01-01 12:00:00/2025-01-03 12:00:00])
    Date.range(~D[2025-01-02], ~D[2025-01-02])

    iex > als_daterange(~Z[2025-01-01 12:00:00/2025-01-03 12:00:00], truncate_from: false)
    Date.range(~D[2025-01-01], ~D[2025-01-02])
  """
  def als_daterange(%Date.Range{} = zeitraum), do: zeitraum

  def als_daterange(zeitraum, opts \\ []) do
    intervall = als_intervall(zeitraum)
    from = NaiveDateTime.to_date(intervall.from)
    until = NaiveDateTime.to_date(intervall.until)

    date_only_range =
      Map.get(intervall, :right_open, false) == true and
        ~T[00:00:00] == NaiveDateTime.to_time(intervall.from) and
        ~T[00:00:00] == NaiveDateTime.to_time(intervall.until)

    truncate_from = Keyword.get(opts, :truncate_from, true)
    truncate_until = !date_only_range or Keyword.get(opts, :truncate_until, true)

    from =
      if truncate_from and ~T[00:00:00] != NaiveDateTime.to_time(intervall.from),
        do: Date.add(from, 1),
        else: from

    until =
      if truncate_until and ~T[00:00:00] == NaiveDateTime.to_time(intervall.until),
        do: Date.add(until, -1),
        else: until

    Date.range(from, until)
  end

  @doc """
  Berechnet die Dauer eines Zeitraums.

  Für die verfügbaren Einheiten siehe: `Timex.Interval.duration/2`
  """
  @spec dauer(t, duration_unit) :: Timex.Duration.t() | {:error, any}
  def dauer(zeitraum, unit \\ :duration),
    do: Timex.Interval.duration(als_intervall(zeitraum), unit)

  @doc """
  Berechnet ob sich zwei Zeiträume überschneiden.
  """
  @spec ueberschneidung?(t, t) :: boolean
  def ueberschneidung?(zeitraum, andere_zeitraum) do
    Timex.Interval.overlaps?(als_intervall(zeitraum), als_intervall(andere_zeitraum))
  end

  @doc """
  Berechnet ob ein Zeitraum vollständig in einem anderen Zeitraum enthalten ist.
  """
  @spec teil_von?(zu_testende_periode :: t, periode :: t) :: boolean
  def teil_von?(zu_testender_zeitraum, zeitraum) do
    Timex.Interval.contains?(als_intervall(zeitraum), als_intervall(zu_testender_zeitraum))
  end

  @doc """
  Zieht einen Zeitraum von einem anderen Zeitraum ab.

  Es wird also der erste Zeitraum ohne die Überlappungen mit dem zweiten
  Zeitraum zurückgegeben.

  In beiden Parameter können auch Listen von Zeiträumen angegeben werden.
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

  # Zieht von einem einzelnen Zeitraum einen anderen ab. Für tolle Beispiele siehe
  # https://hexdocs.pm/timex/3.5.0/Timex.Interval.html#difference/2
  def differenz(basis_intervall, abzuziehendes_intervall) do
    Timex.Interval.difference(
      ZeitraumProtokoll.als_intervall(basis_intervall),
      ZeitraumProtokoll.als_intervall(abzuziehendes_intervall)
    )
  end

  @doc """
  Ermittelt die Überschneidung zweier Zeiträume.

  Gibt `nil` zurück wenn die Zeiträume sich nicht überschneiden.

  Die Überschneidung kann mithilfe der differenz ermittelt werden:

  <pre>
  AB - (AB - BC) = B
  AB - (A) = B
  B = B
  </pre>

  ## Beispiele

      iex> ueberschneidung(~v[2024-01], ~D[2024-01-02])
      %Timex.Interval{from: ~N[2024-01-02 00:00:00], until: ~N[2024-01-03 00:00:00]}

      iex> ueberschneidung(~v[2024-01], ~D[2024-01-10])
      nil

  Zur Begrenzung mehrerer Zeiträume auf z.B. einen Monat kann mit map & filter
  erreicht werden.

      ...> Enum.map(wochen, &ueberschneidung(&1, ~M[2024-01]) |> Enum.reject(&is_nil/1)
      [
        %Timex.Interval{from: ~N[2024-01-01 00:00:00], until: ~N[2024-01-08 00:00:00]},
        %Timex.Interval{from: ~N[2024-01-08 00:00:00], until: ~N[2024-01-15 00:00:00]},
        %Timex.Interval{from: ~N[2024-01-15 00:00:00], until: ~N[2024-01-22 00:00:00]},
        %Timex.Interval{from: ~N[2024-01-22 00:00:00], until: ~N[2024-01-29 00:00:00]},
        %Timex.Interval{from: ~N[2024-01-29 00:00:00], until: ~N[2024-02-01 00:00:00]},
      ]


  """
  @spec ueberschneidung(t(), t()) :: t() | nil
  def ueberschneidung(a, b) do
    case differenz(a, differenz(a, b)) do
      [ueberschneidung] -> ueberschneidung
      [] -> nil
    end
  end

  @doc """
  Ermittelt die Schnittmenge mehrerer Zeiträume.

  ## Beispiel

      iex> ueberschneidung([~M[2024-01], ~v[2024-05], ~D[2024-01-30]])
      %Timex.Interval{from: ~N[2024-01-30 00:00:00], until: ~N[2024-01-31 00:00:00]},

      iex> ueberschneidung([~D[2024-01-31], ~M[2024-02]])
      nil
  """
  @spec ueberschneidung([t()]) :: t() | nil
  def ueberschneidung([zeitraum]), do: zeitraum

  def ueberschneidung([zeitraum | weitere_zeitraeume]) when is_list(weitere_zeitraeume) do
    case ueberschneidung(weitere_zeitraeume) do
      nil -> nil
      schnittmenge -> ueberschneidung(zeitraum, schnittmenge)
    end
  end
end
