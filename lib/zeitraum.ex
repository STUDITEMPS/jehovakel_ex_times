defmodule Shared.Zeitraum do
  @moduledoc """
  Funktionen zur Handhabung von Zeiträumen.

  Diese funktionen arbeiten auf dem `Shared.ZeitraumProtokoll`. Es existieren
  implementierngen für: `t:Shared.Week.t/0`, `t:Shared.Month.t/0` `t:Date.t/0`
  und `t:DateRange.t/0`. Weitere Entities können einfach durch implementierung
  des ZeitraumProtokolls mit unterstützt werden.
  """

  alias Shared.ZeitraumProtokoll

  @type t :: ZeitraumProtokoll.t()

  @doc """
  Konvertiert einen `t:Shared.Zeitraum.t/0` in ein `t:Timex.Interval.t/0`.

  ## Beispiel:

    iex> %Timex.Interval{} = als_intervall(~D[2025-01-01])
  """
  @spec als_intervall(t()) :: Timex.Interval.t()
  defdelegate als_intervall(zeitraum), to: ZeitraumProtokoll

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
  def dauer(zeitraum, einheit \\ :duration),
    do: Timex.Interval.duration(als_intervall(zeitraum), einheit)

  @doc """
  Testet zwei Zeiträume auf Überschneidung

  ## Beispiel

    iex> ueberschneidung?(~D[2025-01-01], ~v[2025-02])
    false

    iex> ueberschneidung?(~v[2025-05], ~m[2025-01])
    true
  """
  @spec ueberschneidung?(t, t) :: boolean
  def ueberschneidung?(zeitraum, andere_zeitraum) do
    Timex.Interval.overlaps?(als_intervall(zeitraum), als_intervall(andere_zeitraum))
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
  def teil_von?(zu_testender_zeitraum, zeitraum) do
    Timex.Interval.contains?(als_intervall(zeitraum), als_intervall(zu_testender_zeitraum))
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
  [
    %Timex.Interval{from: ~N[2024-01-02 00:00:00], until: ~N[2024-01-04 00:00:00], step: [seconds: 1]},
    %Timex.Interval{from: ~N[2024-01-05 00:00:00], until: ~N[2024-01-07 00:00:00], step: [seconds: 1]}
  ]
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
  def differenz(basis_intervall, abzuziehendes_intervall) do
    Timex.Interval.difference(
      ZeitraumProtokoll.als_intervall(basis_intervall),
      ZeitraumProtokoll.als_intervall(abzuziehendes_intervall)
    )
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
  %Timex.Interval{from: ~N[2025-01-27 00:00:00], until: ~N[2025-02-01 00:00:00], step: [seconds: 1]}

  iex> ueberschneidung(~D[2025-01-01], ~D[2025-01-02])
  nil

  iex> ueberschneidung(~D[2025-01-01], ~D[2025-01-01])
  ~D[2025-01-01]
  """
  @spec ueberschneidung(t(), t()) :: t() | nil
  def ueberschneidung(a, b) do
    case differenz(a, differenz(a, b)) do
      [ueberschneidung] -> ueberschneidung
      [] -> nil
    end
  end
end
